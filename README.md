# README

A REST API to ADD identity providers in the OKTA tenant.

## starting the service

- App expects the follow environment variables

```bash
    export OKTA_API_TOKEN=""
    export OKTA_TENANT=""
    export IDP_POLICY_ID=""
```

- Install the project dependencies.

```bash
    bin/bundle install
```

- Running the migration

```bash
 bin/rails db:migrate
```

- Run the server

```bash
    bin/rails server
```

## API

Create an Identity provider in the okta tenant.

**URL** : `/api/provider`

**Method** : `POST`

**Content Type** : `multipart/form-data`

**Data constraints**

    * name
    * domains
    * file

```

  "name"      "[unicode 64 chars max]"
  "domains"   "[csv separated domain values]"
  "file"      "[meta data file to upload]"

```

**Data example** All fields must be sent.

## Success Response

**Condition** : If everything is OK and an IDP didn't exist for this tenant with the name provider.

**Code** : `201 CREATED`

**Response example**

```json
{
  "external_idp": {
    "certificate": "MIIDDTCCAfWgAwIBAgIJBgerN1HSn57VMA0GCSqGSIb3DQEBCwUAMCQxIjAgBgNVBAMTGWRldi1vNHVyZ2Z2ay51cy5hdXRoMC5jb20wHhcNMjEwODA1MTk0ODU0WhcNMzUwNDE0MTk0ODU0WjAkMSIwIAYDVQQDExlkZXYtbzR1cmdmdmsudXMuYXV0aDAuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApQyoMj1q+uYH0DWj9x9FJrW1fsg9/KE302DPBNtvZ/cI106g2NCdiysXs8z1IXArs9LI8nGQ589FdGWHLS4pJJYTI8/WoIjA7SSrvY7nARZKq/0wcyprgYlmx+gqhEf7pcuULfCL30....",
    "name": "oauth0",
    "sso_url": "https://dev-o4urgfvk.us.auth0.com/samlp/tLuZESr9anYeEbs1hNP30STUsa0dZJPb",
    "issuer": "urn:dev-o4urgfvk.us.auth0.com",
    "audience": "urn:dev-o4urgfvk.us.auth0.com",
    "domains": ["svanpro.com"]
  }
}
```

```

```
