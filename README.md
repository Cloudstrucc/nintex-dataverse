# Nintex Digital Signature Activity - Complete Automated Deployment

**Fully automated deployment** for Nintex AssureSign Digital Signature Activity in Microsoft Dataverse with automatic configuration of Status Reasons, Activity enablement, and least-privilege security roles.

## 🎯 Overview

This script **completely automates**:
1. ✅ **Schema Creation** - Activity table with 10 custom fields
2. ✅ **Status Reason Configuration** - 6 custom status values automatically configured
3. ✅ **Activity Enablement** - Automatically enables activities on Account, Contact, and Case
4. ✅ **Security Role Creation** - Minimal privilege role (no System Administrator needed!)
5. ✅ **Privilege Assignment** - Automatic CRUD permissions setup

**Result:** Run one command, get a fully configured digital signature system! 🚀

## ✅ Prerequisites

### 1. Install Tools
```bash
# macOS (using Homebrew)
brew install jq

# jq is required for JSON processing
# curl is pre-installed on macOS
```

### 2. Azure App Registration

1. **Azure Portal** → **App Registrations** → **New registration**
2. **Name:** "Nintex Digital Signature API"
3. **API Permissions** → Add: **Dynamics CRM** → `user_impersonation`
4. **Certificates & secrets** → New client secret → Copy and save
5. Note your **Application (client) ID** and **Directory (tenant) ID**

### 3. Create Application User in Dataverse

**Option A: Power Platform CLI**
```bash
pac admin create-user \
  --environment https://yourorg.crm3.dynamics.com \
  --application-id <client-id> \
  --role "System Administrator"
```

**Option B: Power Platform Admin Center (UI)**
1. https://admin.powerplatform.microsoft.com
2. Environment → **Settings** → **Users + permissions** → **Application users**
3. **+ New app user** → Select your app → Assign "System Administrator" (temporary)

> **Note:** The script will create a minimal privilege role that you'll assign later.

## 📝 Configuration

### 1. Create Config File
```bash
cp nintex-config-sample.json config.json
nano config.json  # or use your preferred editor
```

### 2. Configure Settings
```json
{
  "clientId": "12345678-1234-1234-1234-123456789abc",
  "tenantId": "87654321-4321-4321-4321-cba987654321",
  "crmInstance": "yourorg",
  "clientSecret": "your~client~secret~here",
  "publisherPrefix": "cs",
  "publisherName": "Cloudstrucc Inc",
  "roleName": "Nintex Digital Signature API User",
  "roleDescription": "API user for Nintex digital signature operations"
}
```

**Configuration Fields:**

| Field | Description | Example |
|-------|-------------|---------|
| `clientId` | Azure App Registration Client ID | From Azure Portal |
| `tenantId` | Azure AD Tenant ID | From Azure Portal |
| `crmInstance` | Dataverse org name | `yourorg` (from yourorg.crm3.dynamics.com) |
| `clientSecret` | App client secret | From Azure Portal |
| `publisherPrefix` | Custom table prefix | `cs` (Cloudstrucc) |
| `publisherName` | Publisher display name | `Cloudstrucc Inc` |
| `roleName` | Security role name | Customize as needed |
| `roleDescription` | Role description | Customize as needed |

## 🚀 Deployment Modes

The script supports **four deployment modes**:

### Mode 1: Full Deployment ⭐ **RECOMMENDED**
Complete automated setup - creates everything and configures all settings.

```bash
chmod +x deploy-nintex-activity.sh
./deploy-nintex-activity.sh config.json
# OR explicitly:
./deploy-nintex-activity.sh config.json all
```

**This mode:**
- ✅ Creates activity table and 10 custom fields
- ✅ Configures all 6 Status Reason values
- ✅ Enables activities on Account, Contact, Case
- ✅ Creates security role with minimal privileges
- ✅ Publishes all customizations

**Duration:** ~2-3 minutes

### Mode 2: Schema Only
Creates only the database schema without configuration or security.

```bash
./deploy-nintex-activity.sh config.json schema
```

**Use when:** You want to manually configure Status Reasons and security.

### Mode 3: Security Role Only
Creates only the security role with privileges.

```bash
./deploy-nintex-activity.sh config.json security
# OR
./deploy-nintex-activity.sh config.json role-only
```

**Use when:** Schema exists and you need to add/update the security role.

### Mode 4: Configure Only
Configures Status Reasons and enables activities (requires schema to exist).

```bash
./deploy-nintex-activity.sh config.json configure
```

**Use when:** Schema exists but you need to add Status Reasons and enable activities.

## 📋 What Gets Automated

### ✅ Automatically Created

#### 1. Activity Table
- **Logical Name:** `cs_digitalsignatureactivity`
- **Display Name:** Digital Signature Activity
- **Type:** Activity (Timeline-enabled)

#### 2. Custom Fields (10 total)

| Field Name | Type | Size | Description |
|------------|------|------|-------------|
| Recipient Email | Email | 100 | Signer's email address |
| Recipient Name | String | 200 | Signer's full name |
| Document Content | Memo | 1MB | Base64 document to sign |
| Document Name | String | 200 | Document filename |
| Nintex Request ID | String | 100 | Nintex API tracking ID |
| Signed Document | Memo | 1MB | Base64 signed document |
| Signature Date | DateTime | - | When signed |
| Request Date | DateTime | - | When sent |
| Expiry Date | DateTime | - | Request expiration |
| Callback URL | URL | 500 | Webhook for updates |

#### 3. Status Reason Values

| State | Status Code | Label |
|-------|-------------|-------|
| Open (0) | 1 | Draft |
| Open (0) | 2 | Pending Signature |
| Open (0) | 3 | Failed to Send |
| Completed (1) | 4 | Signed |
| Cancelled (2) | 5 | Declined |
| Cancelled (2) | 6 | Expired |

#### 4. Activity Enablement
- ✅ **Account** - Activities enabled
- ✅ **Contact** - Activities enabled
- ✅ **Case (Incident)** - Activities enabled

#### 5. Security Role

**Role Name:** Nintex Digital Signature API User

**Digital Signature Activity Privileges (Global):**
- Create, Read, Write, Delete
- Append, AppendTo, Assign, Share

**Related Entity Privileges (Read Only):**
- Account, Contact, Case, Opportunity - Global Read
- ActivityPointer, SystemUser, Team, BusinessUnit - Global Read
- Email - Local Read

**Result:** API user can manage signatures without System Administrator access! 🔒

## 🎬 Complete Deployment Workflow

### Step 1: Prepare Configuration
```bash
# Clone or download the script
cp nintex-config-sample.json config.json

# Edit with your credentials
nano config.json
```

### Step 2: Run Deployment
```bash
# Make executable (first time only)
chmod +x deploy-nintex-activity.sh

# Run full deployment
./deploy-nintex-activity.sh config.json all
```

### Step 3: Assign Security Role to API User

**Via Power Platform Admin Center:**
1. https://admin.powerplatform.microsoft.com
2. Your environment → **Settings** → **Users + permissions** → **Users**
3. Find your application user
4. **Manage Roles**
5. ❌ **Remove** "System Administrator"
6. ✅ **Add** "Nintex Digital Signature API User"
7. **Save**

### Step 4: Test the Deployment
```bash
# Test creating an activity via API
curl -X POST "https://yourorg.crm3.dynamics.com/api/data/v9.2/cs_digitalsignatureactivities" \
  -H "Authorization: Bearer $YOUR_API_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "Test Signature Request",
    "cs_recipientemail": "test@example.com",
    "cs_recipientname": "Test User",
    "statecode": 0,
    "statuscode": 2
  }'
```

### Step 5: Test Timeline Integration
1. Open any **Account** record in Dynamics
2. Navigate to **Timeline**
3. Click **+** → **Digital Signature Activity**
4. Fill in the quick create form
5. **Save** and verify it appears

## 🔧 Staged Deployment (Advanced)

For environments where you want more control:

```bash
# Day 1: Create schema only
./deploy-nintex-activity.sh config.json schema

# ... manually review, test ...

# Day 2: Configure Status Reasons and enable activities
./deploy-nintex-activity.sh config.json configure

# ... verify configuration ...

# Day 3: Create security role
./deploy-nintex-activity.sh config.json security

# ... assign to API user ...
```

## 🧪 Testing & Validation

### Test 1: Verify Schema
```bash
# Check if table exists
curl "https://yourorg.crm3.dynamics.com/api/data/v9.2/EntityDefinitions(LogicalName='cs_digitalsignatureactivity')?$select=DisplayName,LogicalName" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Test 2: Verify Status Reasons
```bash
# Get status code metadata
curl "https://yourorg.crm3.dynamics.com/api/data/v9.2/EntityDefinitions(LogicalName='cs_digitalsignatureactivity')/Attributes(LogicalName='statuscode')" \
  -H "Authorization: Bearer $TOKEN" | jq '.OptionSet.Options'
```

### Test 3: Verify Activity Enablement
```bash
# Check Account entity
curl "https://yourorg.crm3.dynamics.com/api/data/v9.2/EntityDefinitions(LogicalName='account')?$select=HasActivities" \
  -H "Authorization: Bearer $TOKEN"
```

### Test 4: Verify Security Role
```bash
# Find the role
curl "https://yourorg.crm3.dynamics.com/api/data/v9.2/roles?\$filter=name eq 'Nintex Digital Signature API User'&\$select=roleid,name" \
  -H "Authorization: Bearer $TOKEN" | jq

# Get role privileges count
curl "https://yourorg.crm3.dynamics.com/api/data/v9.2/roles(<role-id>)/roleprivileges?\$count=true" \
  -H "Authorization: Bearer $TOKEN"
```

### Test 5: Create Activity as API User
```bash
# Get token as API user
TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=https://yourorg.crm3.dynamics.com/.default" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Create test activity
curl -X POST "https://yourorg.crm3.dynamics.com/api/data/v9.2/cs_digitalsignatureactivities" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "API Test Activity",
    "cs_recipientemail": "test@Cloudstrucc.com",
    "cs_recipientname": "Test User",
    "statuscode": 1
  }' | jq
```

## 🛠️ Troubleshooting

### Issue: Authentication Failed
```bash
# Check credentials
jq '.clientId, .tenantId, .clientSecret' config.json

# Test authentication manually
curl -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=https://yourorg.crm3.dynamics.com/.default" \
  -d "grant_type=client_credentials"
```

### Issue: Status Reasons Not Created
This is usually not critical. Status Reasons may already exist or have conflicts with default values.

**Check manually:**
```bash
curl "https://yourorg.crm3.dynamics.com/api/data/v9.2/EntityDefinitions(LogicalName='cs_digitalsignatureactivity')/Attributes(LogicalName='statuscode')" \
  -H "Authorization: Bearer $TOKEN" | jq '.OptionSet.Options[] | {Value, Label}'
```

**Add manually:** Power Apps → Tables → Digital Signature Activity → Columns → Status Reason → Add options

### Issue: Activities Not Enabled
The script attempts to enable activities, but this may fail if entities have restrictions.

**Enable manually:**
1. Power Apps → Tables
2. Select Account/Contact/Case
3. **Properties** → **Enable activities** ✓
4. Save

### Issue: API User Permissions Denied

**Verify role assignment:**
```bash
# Get user's roles
curl "https://yourorg.crm3.dynamics.com/api/data/v9.2/systemusers(<user-id>)/systemuserroles_association" \
  -H "Authorization: Bearer $TOKEN"
```

**Verify privileges:**
```bash
# Check privileges on activity table
curl "https://yourorg.crm3.dynamics.com/api/data/v9.2/privileges?\$filter=contains(Name,'cs_digitalsignatureactivity')" \
  -H "Authorization: Bearer $TOKEN" | jq '.value[] | {Name, PrivilegeId}'
```

### Issue: Rate Limiting (HTTP 429)
The script includes automatic retry with 5-second delays. If you still encounter rate limits:

1. Increase sleep time in script: `sleep 5` → `sleep 10`
2. Run in stages (schema → configure → security)
3. Contact Microsoft support

## 📊 Deployment Output Example

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Checking Prerequisites
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ jq found
✅ curl found
✅ Config file loaded: config.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Reading Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ️  Deployment Mode: all
ℹ️  Publisher Prefix: cs
ℹ️  Security Role: Nintex Digital Signature API User

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Creating Digital Signature Activity Entity
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Activity entity created successfully!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Creating Custom Attributes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ ✓ Created: Recipient Email
✅ ✓ Created: Recipient Name
[... 8 more fields ...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Configuring Status Reason Values
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ ✓ Added: Draft
✅ ✓ Added: Pending Signature
[... 4 more status reasons ...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Enabling Activities on Target Entities
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ ✓ Enabled activities on Account
✅ ✓ Enabled activities on Contact
✅ ✓ Enabled activities on Case

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Creating Security Role
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Security role created! ID: abc-123-def...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▶ Deployment Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Digital Signature Activity created successfully!
✅ Post-Deployment Configuration Applied!
✅ Security Role configured successfully!

💡 Tip: All automated configurations have been applied!
```

## 🔐 Security Best Practices

### 1. Protect Config Files
```bash
# Add to .gitignore
echo "config.json" >> .gitignore
echo "*.json" >> .gitignore
echo "!*-sample.json" >> .gitignore
```

### 2. Use Environment Variables
```bash
export NINTEX_SECRET="your-secret"
jq --arg secret "$NINTEX_SECRET" '.clientSecret = $secret' config-template.json > config.json
```

### 3. Rotate Secrets Regularly
- Azure Portal → App Registrations → Certificates & secrets
- Create new secret
- Update config.json
- Delete old secret after testing

### 4. Use Azure Key Vault (Production)
```bash
# Store secret
az keyvault secret set --vault-name yourkeyvault --name nintex-secret --value "..."

# Retrieve and use
SECRET=$(az keyvault secret show --vault-name yourkeyvault --name nintex-secret --query value -o tsv)
jq --arg secret "$SECRET" '.clientSecret = $secret' config-template.json > config.json
```

## 📚 Next Steps

After successful deployment:

1. **Create Forms**
   - Quick Create form for Timeline
   - Main form with all fields
   - Add PCF component if applicable

2. **Deploy C# Plugin**
   - Create, Update message handlers
   - Nintex API integration
   - Webhook callback handling

3. **Configure Power Automate**
   - Automated workflows
   - Notification flows
   - Document processing

4. **Set Up Monitoring**
   - Activity dashboards
   - Signature tracking reports
   - Error logging

5. **Train Users**
   - Timeline-based signature requests
   - Status management
   - Document handling

## 📖 Additional Resources

- [Dataverse Activities](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/activity-entities)
- [Security Roles](https://learn.microsoft.com/en-us/power-platform/admin/security-roles-privileges)
- [Application Users](https://learn.microsoft.com/en-us/power-platform/admin/manage-application-users)
- [Nintex AssureSign API](https://help.nintex.com/en-US/assuresign/)

---

**Script Version:** 3.0.0  
**Publisher:** Cloudstrucc Inc  
**Last Updated:** January 2026  
**Tested On:** macOS Sonoma 14.x (M4 Pro, M3, M2, M1, Intel)

**New in v3.0:**
- ✅ Automatic Status Reason configuration
- ✅ Automatic Activity enablement
- ✅ Cloudstrucc branding
- ✅ Configure mode for post-deployment