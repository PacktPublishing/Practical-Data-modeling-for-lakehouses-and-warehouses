SELECT
	transaction_type,
	transaction_status,
	channel_id,
	count(*) as transaction_count,
	sum(transaction_amount) as total_exposure,
	sum(case when transaction_status = 'PE'
						then transaction_amount else 0 end) as pending_exposure,
	sum(case when transaction_status = 'RE'
						then transaction_amount else 0 end) as reversed_amount
FROM edw.fact_transaction
WHERE date_id = '20240315'
GROUP BY transaction_type, transaction_status, channel_id
ORDER BY total_exposure DESC;