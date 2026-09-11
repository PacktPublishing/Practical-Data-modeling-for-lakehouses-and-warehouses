SELECT
	date_id,
	count(*) as transaction_count,
	sum(transaction_amount) as total_amount,
	sum(fee_amount) as total_fees_amount,
	sum(vat_amount) as total_vat_amount,
	avg(transaction_amount) as avg_transaction_amount,
	min(transaction_amount) as min_transaction_amount,
	max(transaction_amount) as max_transaction_amount
FROM edw.fact_transaction
WHERE date_id between 20240101 and 20240131 -- January 2024
GROUP BY date_id
ORDER BY date_id;