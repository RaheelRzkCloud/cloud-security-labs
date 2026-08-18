# Manual Build Steps (Azure Portal)

Before writing the Terraform version, this was built manually in the Azure portal to understand exactly what each setting does.

1. **Created an App Service** (Linux, F1 free tier) in a dedicated resource group.
2. **Enabled a System-assigned Managed Identity** on the App Service — Settings → Identity → Status: On.
3. **Created a Key Vault** using the Azure RBAC permission model (not the older vault access policy model), so access is managed consistently with standard Azure role assignments.
4. **Granted the App Service's Managed Identity the `Key Vault Secrets User` role** on the vault — Access control (IAM) → Add role assignment → assigned to the Managed Identity, not a user.
5. **Added a test secret** in the vault.
6. **Added a Key Vault reference** in the App Service's environment variables, using the full secret URI:
   ```
   @Microsoft.KeyVault(SecretUri=https://<vault-name>.vault.azure.net/secrets/<secret-name>/<version>)
   ```
7. **Confirmed resolution** via the Key Vault Reference Details panel — status showed `Resolved`, with the identity listed as `System assigned managed identity`, confirming the App Service authenticated to Key Vault without any stored credential.

## Notes

- My own user account initially had no access to view the vault's secrets, despite having created the vault — RBAC applies uniformly, so I had to separately grant myself a role (`Key Vault Secrets Officer`) to manage it.
- The Key Vault reference syntax needs the exact secret version path, not just the vault's base URL — the full identifier is available on the secret's version page in the portal.

