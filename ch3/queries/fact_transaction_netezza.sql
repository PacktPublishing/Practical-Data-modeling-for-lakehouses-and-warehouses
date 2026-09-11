CREATE TABLE edw.fact_transaction
(
	transaction_id BIGINT NOT NULL,
	account_id INTEGER NOT NULL,
	customer_id INTEGER NOT NULL,
	date_id INTEGER NOT NULL,
	channel_id BYTEINT NOT NULL,
	product_id SMALLINT NOT NULL,
	currency_id BYTEINT NOT NULL,
	country_id SMALLINT,
	branch_id SMALLINT,
	transaction_ref VARCHAR(50) NOT NULL,
	transaction_type CHAR(3),
	transaction_status CHAR(3),
	payment_method CHAR(4),
	transaction_amount NUMERIC(18,4) NOT NULL,
	transaction_amount_local NUMERIC(18,4),
	authorized_amount NUMERIC(18,4),
	fee_amount NUMERIC(18,4),
	vat_amount NUMERIC(12,4),
	running_balance_amount NUMERIC(18,4),
	foreign_exchange_rate NUMERIC(10,6),
	etl_batch_id INTEGER NOT NULL,
	etl_insert_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	etl_update_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	etl_source_system CHAR(6) NOT NULL,
	record_valid_flag BYTEINT NOT NULL DEFAULT 1
)
DISTRIBUTE ON (account_id)
ORGANIZE ON (date_id, transaction_type);