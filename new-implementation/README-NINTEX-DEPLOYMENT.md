# Nintex AssureSign Dataverse Integration

Complete deployment solution for creating Dataverse tables that mirror the Nintex AssureSign API, enabling middleware functionality.

## 📋 Overview

This solution creates 8 Dataverse tables that mirror the Nintex AssureSign API structure:

1. **Envelope** - Signature request containers
2. **Document** - Individual documents within envelopes
3. **Signer** - Recipients and their signing status
4. **Field** - Signature fields and JotBlocks
5. **Template** - Reusable envelope templates
6. **Auth Token** - API authentication token management
7. **Webhook** - Event notifications from Nintex
8. **API Request** - Request/response logging

## 🚀 Quick Start

### One Command Deployment

```bash
chmod +x deploy-nintex-all.sh
./deploy-nintex-all.sh config.json full
```

That's it! This will:
- ✅ Create all 8 tables with complete schemas
- ✅ Create security role with proper privileges
- ✅ Publish customizations
- ✅ Wait for privilege generation

## 📦 Files Included

### Core Scripts
- `deploy-nintex-all.sh` - **Master orchestration script** (run this)
- `deploy-tables-engine.sh` - Table creation engine
- `create-security-roles.sh` - Security role setup
- `nintex-tables-schema.json` - Table definitions

### Helper Scripts  
- `assign-role-to-user.sh` - Assign role to app user
- `diagnose-access.sh` - Debug permissions
- `list-all-users.sh` - Find application users

### Configuration
- `config.json` - Your deployment settings
- `nintex-config-sample.json` - Example configuration

## ⚙️ Configuration

Update `config.json`:

```json
{
  "clientId": "your-azure-app-id",
  "tenantId": "your-tenant-id",
  "crmInstance": "yourorg",
  "clientSecret": "your-secret",
  "publisherPrefix": "cs",
  "publisherName": "CloudStrucc Inc",
  "roleName": "Nintex API User",
  "roleDescription": "API access for Nintex middleware",
  "appUserName": "Your App User Name"
}
```

## 🎯 Deployment Modes

### Full Deployment (Default)
Creates tables AND security roles:
```bash
./deploy-nintex-all.sh config.json full
```

### Tables Only
Just create/update tables:
```bash
./deploy-nintex-all.sh config.json tables-only
```

### Security Only
Just create security roles (tables must exist):
```bash
./deploy-nintex-all.sh config.json security-only
```

## 📊 Table Schema

### Envelope Table
Main container for signature requests.

**Key Fields:**
- `cs_name` - Envelope name
- `cs_envelopeid` - Nintex envelope ID
- `cs_status` - Current status
- `cs_subject` - Email subject
- `cs_message` - Email body
- `cs_sentdate` - When sent
- `cs_completeddate` - When completed
- `cs_expirationdate` - Expiry date
- `cs_callbackurl` - Webhook URL

### Document Table
Individual documents within envelopes.

**Key Fields:**
- `cs_name` - Document name
- `cs_documentid` - Nintex document ID
- `cs_envelopeid` - Parent envelope
- `cs_filename` - Original filename
- `cs_filecontent` - Base64 encoded file
- `cs_signedcontent` - Signed document
- `cs_pagecount` - Number of pages

### Signer Table
Recipients who sign documents.

**Key Fields:**
- `cs_name` - Signer name
- `cs_signerid` - Nintex signer ID
- `cs_email` - Email address
- `cs_signerstatus` - Status (Pending, Signed, Declined)
- `cs_signerorder` - Signing sequence
- `cs_signeddate` - When signed
- `cs_declinedreason` - Reason if declined
- `cs_authenticationtype` - Auth method

### Field Table
Signature fields, text fields, checkboxes (JotBlocks).

**Key Fields:**
- `cs_name` - Field name
- `cs_fieldtype` - Type (signature, initial, text, date, checkbox)
- `cs_documentid` - Parent document
- `cs_signerid` - Assigned signer
- `cs_positionx`, `cs_positiony` - Coordinates (0-1)
- `cs_width`, `cs_height` - Dimensions (0-1)
- `cs_pagenumber` - Page location
- `cs_value` - Field value

### Template Table
Reusable envelope templates.

**Key Fields:**
- `cs_name` - Template name
- `cs_templateid` - Nintex template ID
- `cs_description` - Description
- `cs_category` - Category
- `cs_isactive` - Active status
- `cs_ispublic` - Shared/private

### Auth Token Table
API authentication token management.

**Key Fields:**
- `cs_name` - Token name
- `cs_token` - Bearer token value
- `cs_apiusername` - API username
- `cs_contextusername` - Context user email
- `cs_issuedat` - Issue timestamp
- `cs_expiresat` - Expiry timestamp
- `cs_isactive` - Valid status

### Webhook Table
Event notifications from Nintex.

**Key Fields:**
- `cs_name` - Webhook name
- `cs_webhookid` - Webhook ID
- `cs_envelopeid` - Related envelope
- `cs_eventtype` - Event (Signed, Declined, Completed)
- `cs_eventdate` - When occurred
- `cs_payload` - JSON payload
- `cs_processed` - Processed status
- `cs_errorlog` - Processing errors

### API Request Table
Log of API calls to Nintex.

**Key Fields:**
- `cs_name` - Request description
- `cs_requestid` - Request ID
- `cs_endpoint` - API endpoint
- `cs_method` - HTTP method
- `cs_requestbody` - Request JSON
- `cs_responsebody` - Response JSON
- `cs_statuscode` - HTTP status
- `cs_responsetime` - Response time (ms)
- `cs_success` - Success flag

## 🔐 Security

### Assigning the Security Role

After deployment, assign the role to your app user:

```bash
./assign-role-to-user.sh config.json
```

Or if user name not in config:
```bash
./assign-role-to-user.sh config.json "App User Name"
```

### Role Privileges

The created role has:
- ✅ Full CRUD on all 8 Nintex tables (Global depth)
- ✅ Read access to SystemUser and BusinessUnit
- ❌ No access to other entities (least privilege)

## 🧪 Testing

### Verify Deployment

```bash
# Check what you can access
./diagnose-access.sh config.json

# List all application users
./list-all-users.sh config.json
```

### Access Tables in Power Apps

```
https://yourorg.crm3.dynamics.com/main.aspx
```

Navigate to: **Tables** → Find your `cs_*` tables

## 🔄 Update Existing Deployment

The scripts handle **upsert** automatically:
- If table exists → Adds missing attributes
- If table doesn't exist → Creates it
- If attribute exists → Skips it

Safe to run multiple times:
```bash
./deploy-nintex-all.sh config.json full
```

## 🏗️ Architecture

```
Dataverse OData API
       ↓
  Your Middleware
       ↓
  Nintex AssureSign API
```

### Middleware Flow

1. **Client** → Calls Dataverse OData API
2. **Plugin/Flow** → Intercepts create/update on Nintex tables
3. **Middleware** → Calls Nintex AssureSign API
4. **Response** → Updates Dataverse records
5. **Webhook** → Nintex calls back on events
6. **Update** → Status synced to Dataverse

## 📝 Customization

### Add More Tables

Edit `nintex-tables-schema.json`:

```json
{
  "tables": [
    {
      "logicalName": "newtable",
      "displayName": "New Table",
      "displayNamePlural": "New Tables",
      "description": "Description",
      "primaryAttribute": {
        "schemaName": "Name",
        "displayName": "Name",
        "description": "Name field",
        "maxLength": 200
      },
      "attributes": [
        {
          "logicalName": "field1",
          "schemaName": "Field1",
          "displayName": "Field 1",
          "description": "First field",
          "type": "String",
          "maxLength": 100
        }
      ]
    }
  ]
}
```

Then redeploy:
```bash
./deploy-nintex-all.sh config.json tables-only
```

### Supported Field Types

- `String` - Text fields (Email, Phone, Text, Url formats)
- `Memo` - Long text
- `Integer` - Whole numbers
- `Decimal` - Decimal numbers
- `Boolean` - Yes/No
- `DateTime` - Date and time
- `Date` - Date only

## 🐛 Troubleshooting

### "Could not find app user"
Run diagnostics:
```bash
./list-all-users.sh config.json
```
Copy exact name to config.json

### "Privilege not found"
Tables need to be published first:
```bash
./publish-table.sh config.json
```
Wait 30 seconds, then retry security setup.

### "HTTP 401 Unauthorized"
Check your credentials in config.json:
- `clientId`
- `clientSecret`
- `tenantId`

### "Cannot read systemusers"
Your app user needs System Administrator temporarily:
1. Go to Power Platform Admin Center
2. Environments → Your env → Settings
3. Users + permissions → Application users
4. Find your app → Manage roles
5. Add System Administrator
6. Run deployment
7. Remove System Administrator

## 📚 Resources

- [Nintex AssureSign API Docs](https://account.assuresign.net/api/v3.7/documentation)
- [Dataverse Web API Reference](https://docs.microsoft.com/power-apps/developer/data-platform/webapi/overview)
- [Power Platform Admin Center](https://admin.powerplatform.microsoft.com/)

## 🤝 Support

For issues or questions:
1. Run diagnostics: `./diagnose-access.sh config.json`
2. Check the logs in terminal output
3. Verify config.json settings

## 📄 License

This is a deployment tool for CloudStrucc Inc's Nintex integration project.

---

**Made with ❤️ for Leonardo Company Canada**
