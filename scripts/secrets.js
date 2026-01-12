#!/usr/bin/env node
/**
 * Secrets Manager CLI - Flow B (Third-Party Secrets)
 *
 * NAMING CONVENTION: /{env}/{app}/{purpose}
 *
 * Commands:
 *   node secrets.js seed    - Seed third-party secrets
 *   node secrets.js read    - Read all secrets
 *   node secrets.js list    - List all secret names
 *
 * Environment:
 *   USE_LOCALSTACK=true     - Use LocalStack (default: true)
 *   PROJECT_NAME=myapp      - Project name (default: myapp)
 *   ENVIRONMENT=development - Environment (default: development)
 *
 * Install: npm install @aws-sdk/client-secrets-manager
 */

import {
  SecretsManagerClient,
  GetSecretValueCommand,
  PutSecretValueCommand,
  DescribeSecretCommand,
} from "@aws-sdk/client-secrets-manager";

// Environment to short name mapping
const ENV_SHORT = {
  development: "dev",
  staging: "staging",
  production: "prod",
};

// Configuration
const config = {
  isLocalStack: process.env.USE_LOCALSTACK !== "false",
  endpoint: process.env.LOCALSTACK_ENDPOINT || "http://localhost:4566",
  region: process.env.AWS_REGION || "us-east-1",
  projectName: process.env.PROJECT_NAME || "myapp",
  environment: process.env.ENVIRONMENT || "development",
};

// Get short environment name
function getEnvShort() {
  return ENV_SHORT[config.environment] || config.environment;
}

// Secret definitions - Flow B (Third-Party)
// NAMING: /{env}/{app}/{purpose}
const secretDefs = {
  thirdParty: {
    stripe: {
      purpose: "stripe-api-key",
      description: "Stripe API key",
      envVar: "STRIPE_API_KEY",
      default: { api_key: "sk_test_demo_replace_with_real_key" },
      vendor: "Stripe Dashboard",
    },
    sendgrid: {
      purpose: "sendgrid-api-key",
      description: "SendGrid API key",
      envVar: "SENDGRID_API_KEY",
      default: { api_key: "SG.demo_replace_with_real_key" },
      vendor: "SendGrid Settings",
    },
    oauth: {
      purpose: "oauth-credentials",
      description: "OAuth credentials",
      envVar: "OAUTH_CLIENT",
      default: {
        client_id: "demo-client-id",
        client_secret: "demo-client-secret",
        token_url: "https://auth.example.com/oauth/token",
      },
      vendor: "OAuth Provider",
    },
  },
};

// Build full secret name
// Format: /{env}/{app}/{purpose}
function getSecretName(def) {
  return `/${getEnvShort()}/${config.projectName}/${def.purpose}`;
}

// Create client
function createClient() {
  const clientConfig = { region: config.region };

  if (config.isLocalStack) {
    clientConfig.endpoint = config.endpoint;
    clientConfig.credentials = {
      accessKeyId: "test",
      secretAccessKey: "test",
    };
  }

  return new SecretsManagerClient(clientConfig);
}

// Get secret value
async function getSecret(secretName) {
  const client = createClient();

  try {
    const response = await client.send(
      new GetSecretValueCommand({ SecretId: secretName })
    );

    if (response.SecretString) {
      try {
        return JSON.parse(response.SecretString);
      } catch {
        return response.SecretString;
      }
    }
    return null;
  } catch (error) {
    if (error.name === "ResourceNotFoundException") {
      return { error: "Not found - run terraform apply" };
    }
    if (error.message?.includes("secret version")) {
      return { error: "Empty - needs seeding" };
    }
    return { error: error.message };
  }
}

// Put secret value
async function putSecret(secretName, value) {
  const client = createClient();

  try {
    await client.send(
      new PutSecretValueCommand({
        SecretId: secretName,
        SecretString: typeof value === "object" ? JSON.stringify(value) : value,
      })
    );
    return true;
  } catch (error) {
    console.error(`  [ERROR] ${error.message}`);
    return false;
  }
}

// Check if secret exists
async function secretExists(secretName) {
  const client = createClient();

  try {
    await client.send(new DescribeSecretCommand({ SecretId: secretName }));
    return true;
  } catch {
    return false;
  }
}

// Mask value for display
function maskValue(value) {
  if (value?.error) return `[${value.error}]`;
  if (typeof value === "object")
    return JSON.stringify(value).substring(0, 50) + "...";
  if (typeof value === "string" && value.length > 20)
    return value.substring(0, 20) + "...";
  return value;
}

// Parse env var value (handle JSON or plain string)
function parseEnvValue(envValue, defaultValue) {
  if (!envValue) return defaultValue;

  // Try to parse as JSON first
  try {
    return JSON.parse(envValue);
  } catch {
    // If it's a plain string (like an API key), wrap it
    if (typeof defaultValue === "object" && defaultValue.api_key !== undefined) {
      return { api_key: envValue };
    }
    return envValue;
  }
}

// Command: seed
async function cmdSeed() {
  console.log("\n" + "=".repeat(60));
  console.log("FLOW B: Seeding Third-Party Secrets");
  console.log("=".repeat(60));
  console.log(`\nNaming: /{env}/{app}/{system}/{purpose}`);
  console.log(`Example: /${getEnvShort()}/${config.projectName}/stripe-api-key\n`);

  let seeded = 0;
  let skipped = 0;

  for (const [key, def] of Object.entries(secretDefs.thirdParty)) {
    const secretName = getSecretName(def);
    const value = parseEnvValue(process.env[def.envVar], def.default);
    const isDefault = !process.env[def.envVar];

    process.stdout.write(`  ${def.description}... `);

    if (!(await secretExists(secretName))) {
      console.log("[SKIP] Shell not found - run terraform apply first");
      skipped++;
      continue;
    }

    if (await putSecret(secretName, value)) {
      console.log(isDefault ? "[OK] (demo value)" : "[OK] (from env)");
      seeded++;
    }
  }

  console.log("\n" + "-".repeat(60));
  console.log(`Seeded: ${seeded} | Skipped: ${skipped}`);
  console.log("-".repeat(60));

  if (seeded > 0) {
    console.log(`
Next steps:
  1. Your app can now read these secrets at runtime:
     secretsManager.getSecretValue({ SecretId: '/dev/myapp/stripe-api-key' })

  2. For production, set real values via environment:
     STRIPE_API_KEY=sk_live_xxx node scripts/secrets.js seed
`);
  }
}

// Command: read
async function cmdRead() {
  console.log("\n" + "=".repeat(60));
  console.log("FLOW B: Third-Party Secrets");
  console.log("=".repeat(60));
  console.log(`\nNaming: /{env}/{app}/{purpose}\n`);

  for (const [key, def] of Object.entries(secretDefs.thirdParty)) {
    const secretName = getSecretName(def);
    const value = await getSecret(secretName);
    console.log(`  ${def.description}:`);
    console.log(`    Name:   ${secretName}`);
    console.log(`    Value:  ${maskValue(value)}`);
    console.log(`    Source: ${def.vendor}`);
    console.log("");
  }

  console.log("-".repeat(60));
  console.log("Note: Flow A secrets (RDS password) are stored in RDS itself.");
  console.log("Apps should use IAM database authentication to access RDS.");
  console.log("-".repeat(60) + "\n");
}

// Command: list
async function cmdList() {
  console.log("\n" + "=".repeat(60));
  console.log("Third-Party Secret Names (Flow B)");
  console.log("=".repeat(60));
  console.log(`\nNaming: /{env}/{app}/{purpose}\n`);

  for (const [key, def] of Object.entries(secretDefs.thirdParty)) {
    console.log(`  ${def.description}:`);
    console.log(`    ${getSecretName(def)}`);
    console.log(`    Source: ${def.vendor}`);
    console.log("");
  }
}

// Command: help
function cmdHelp() {
  console.log(`
Secrets Manager CLI - Engineering Secret Standard

NAMING CONVENTION: /{env}/{app}/{purpose}
  env:     dev | staging | prod
  app:     project/service name
  purpose: stripe-api-key | sendgrid-api-key | oauth-credentials

This CLI manages Flow B (Third-Party) secrets only.
Flow A secrets are injected directly via write-only arguments.

Usage: node secrets.js <command>

Commands:
  seed    Seed third-party secrets into Secrets Manager
  read    Read and display all third-party secrets
  list    List all third-party secret names

Environment Variables:
  USE_LOCALSTACK=true|false   Use LocalStack (default: true)
  PROJECT_NAME=myapp          Project name (default: myapp)
  ENVIRONMENT=development     Environment (default: development)

  STRIPE_API_KEY=sk_...       Stripe API key for seeding
  SENDGRID_API_KEY=SG....     SendGrid API key for seeding
  OAUTH_CLIENT='{"...}'       OAuth credentials JSON for seeding

Secret Names (examples):
  /dev/myapp/stripe-api-key
  /dev/myapp/sendgrid-api-key
  /dev/myapp/oauth-credentials

Flow Overview:
  FLOW A (TF-Generated):
    - Secrets injected via password_wo to target (e.g., RDS)
    - Not stored in Secrets Manager
    - Rotation: bump rds_password_version in Terraform

  FLOW B (Third-Party):
    - Terraform creates shells, engineer seeds (this CLI)
    - Apps read at runtime via AWS SDK
    - Rotation: get new key from vendor + re-seed here

Examples:
  node secrets.js seed                        # Seed with demo values
  node secrets.js read                        # Read all secrets
  STRIPE_API_KEY=sk_live_xxx seed             # Seed with real Stripe key
  USE_LOCALSTACK=false node secrets.js read   # Read from real AWS
`);
}

// Main
async function main() {
  const command = process.argv[2];

  console.log(
    `\nMode: ${config.isLocalStack ? "LocalStack" : "AWS"} | ` +
    `Project: ${config.projectName} | ` +
    `Env: ${config.environment} (${getEnvShort()})`
  );

  switch (command) {
    case "seed":
      await cmdSeed();
      break;
    case "read":
      await cmdRead();
      break;
    case "list":
      await cmdList();
      break;
    default:
      cmdHelp();
  }
}

main().catch(console.error);

// Export for use as module
export { getSecret, putSecret, secretDefs, getSecretName, createClient };
