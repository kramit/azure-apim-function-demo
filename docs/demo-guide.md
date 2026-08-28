# Demo guide

## Walkthrough

1. Run `scripts/deploy.sh`. It creates a Consumption-tier APIM service, Linux Consumption Function App, and storage account, then deploys the Python source.
2. Call the Function URL directly. It returns a JSON greeting from `GET /api/hello`.
3. Call the APIM endpoint without `Ocp-Apim-Subscription-Key`; APIM returns `401` before the backend is called.
4. Call the same endpoint with a valid subscription key; APIM forwards the request and returns the Function response.

## What is being demonstrated

The Function only implements the greeting. APIM owns client-facing gateway concerns: subscription-key validation and product association. This demo deliberately uses the Consumption tier; that tier does not support `rate-limit-by-key`.

## Final validation checklist

- [ ] Infrastructure deployment succeeded.
- [ ] Function backend returned HTTP 200.
- [ ] APIM endpoint returned HTTP 401 without a subscription key.
- [ ] APIM endpoint returned HTTP 200 with a valid subscription key.
- [ ] Git repository initialised.
- [ ] `.gitignore` created.
- [ ] Repository checked for secrets.
- [ ] No APIM subscription keys committed.
- [ ] No Function keys committed.
- [ ] No Azure credentials committed.
- [ ] GitHub repository created.
- [ ] GitHub repository is public.
- [ ] `main` branch pushed.
- [ ] `origin` remote verified.
- [ ] README renders correctly on GitHub.
- [ ] Published repository contains the complete reproducible demo.
- [ ] GitHub repository URL verified.
