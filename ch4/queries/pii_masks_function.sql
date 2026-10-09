CREATE OR REPLACE FUNCTION omnifin.governance.mask_ssn(ssn STRING)
RETURNS STRING
RETURN CASE
	WHEN is_account_group_member('pii_readers') THEN ssn
	ELSE CONCAT('XXX-XX-', RIGHT(ssn, 4))
END;

CREATE OR REPLACE FUNCTION omnifin.governance.mask_address(customer_address STRING)
RETURNS STRING
RETURN CASE
	WHEN is_account_group_member('pii_readers') THEN customer_address
	ELSE '***REDACTED***'
END;

ALTER TABLE omnifin.raw_vault.sat_customer_pii_omnifin ALTER COLUMN ssn SET MASK omnifin.governance.mask_ssn;

ALTER TABLE omnifin.raw_vault.sat_customer_pii_omnifin ALTER COLUMN customer_address SET MASK omnifin.governance.mask_address;

SELECT customer_hk, ssn, customer_address FROM omnifin.raw_vault.sat_customer_pii_omnifin LIMIT 5;