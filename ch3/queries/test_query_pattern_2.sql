SELECT
	account_id,
	count(*) as atm_transaction_count,
	sum(transaction_amount) as atm_total_withdraw,
	min(date_id) as first_atm_date,
	max(date_id) as last_atm_date
FROM edw.fact_transaction
WHERE transaction_type = 'ATM'
	AND date_id BETWEEN 20240101 AND 20240331 -- Q1 2024
GROUP BY account_id
HAVING SUM(transaction_amount) > 10000
ORDER BY atm_total_withdraw DESC
LIMIT 1000;