CREATE SHARE IF NOT EXISTS customer_behavior_share;

ALTER SHARE customer_behavior_share
  ADD VIEW omnifin.business_vault.customer_profile_v1;

ALTER SHARE customer_behavior_share
  ADD MODEL customer_behavior.models.churn_model;
  
CREATE RECIPIENT IF NOT EXISTS customer_behavior_gcp
  USING ID 'gcp:europe-west1:7f3c9a2e-4b1d-4e8a-9c6f-2d5b8e1a0c47';

GRANT SELECT ON SHARE customer_behavior_share TO RECIPIENT customer_behavior_gcp;