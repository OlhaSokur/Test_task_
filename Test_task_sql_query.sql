-- Task 1
SELECT 
    p.name AS psp_name,
    COALESCE(pc.bin_country, 'Unknown') AS country,
    
    'Payment'::TEXT AS operation_type,
    
    t.status AS transaction_status,
    
    COUNT(t.id) AS transaction_count,
    ROUND(AVG(t.amount), 2) AS avg_amount,
    
    ROUND(
        COUNT(t.id) * 100.0 / NULLIF(SUM(COUNT(t.id)) OVER (PARTITION BY p.name, pc.bin_country), 0), 
        2
    ) AS share_percent

FROM transactions t
JOIN psp p ON t.psp_id = p.id
JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
GROUP BY 
    p.name, 
    pc.bin_country, 
    t.status
ORDER BY 
    p.name, 
    pc.bin_country, 
    transaction_count DESC;





-- Task 2

WITH psp_stats AS (
    SELECT 
        p.name AS psp_name,
        pc.bin_country AS country,
        
        COUNT(*) FILTER (WHERE t.status = 'success') AS success_count,
        COUNT(*) AS total_count
        
    FROM transactions t
    JOIN psp p ON t.psp_id = p.id
    JOIN payment_credentials pc ON t.payment_credentials_id = pc.id
    GROUP BY p.name, pc.bin_country
    
    /* Important note: to ensure statistical significance in production, apply a threshold 
       (HAVING COUNT(*) > 10) to avoid skewed rankings from low-volume providers
    */
),

ranked_psps AS (
    SELECT 
        psp_name,
        country,
        
        ROUND(success_count * 100.0 / NULLIF(total_count, 0), 2) AS success_rate,
        
        DENSE_RANK() OVER (
            PARTITION BY country 
            ORDER BY (success_count * 100.0 / NULLIF(total_count, 0)) DESC
        ) AS rating
    FROM psp_stats
)

SELECT 
    psp_name,
    country,
    success_rate,
    rating
FROM ranked_psps
WHERE rating <= 3
ORDER BY country, rating;