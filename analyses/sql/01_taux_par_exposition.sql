SELECT m.code AS mode, r.country_code, r.year, r.exposure_metric,
       r.accidents, r.fatalities,
       round(r.accidents_per_1e8_exposure::numeric, 2)  AS accidents_pour_1e8,
       round(r.fatalities_per_1e8_exposure::numeric, 2) AS deces_pour_1e8
FROM bi.annual_rates r
JOIN bi.dim_mode m ON m.mode_key = r.transport_mode_id
WHERE NOT r.is_simulated
ORDER BY m.code, r.country_code, r.year;
