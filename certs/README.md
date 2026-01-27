# Konnect Data Plane Certificates

Place your Kong Konnect data plane certificates in this directory:

- `tls.crt` - Data plane certificate
- `tls.key` - Data plane private key

## How to obtain these certificates

1. Log into [Kong Konnect](https://cloud.konghq.com)
2. Navigate to **Gateway Manager** > Select your Control Plane
3. Click **Data Plane Nodes** > **New Data Plane Node**
4. Download the certificates from the configuration modal

These certificates authenticate your data plane to the Konnect control plane.
