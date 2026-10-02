-- =========================================================================
-- queries.sql - your analysis
--
-- Project 1 | SQL: From Data to Insight
-- Team: Nacho
-- Dataset: Inside Airbnb - Barcelona, snapshot 2026-06-24 (CC BY 4.0)
--
-- This is a DELIVERABLE, graded on two things: the SQL, and what you wrote
-- underneath it. A query with no finding recorded is half an answer - in a
-- month you will not remember what it told you, and neither will whoever is
-- marking it.
--
-- Five queries minimum, each earning its place by answering a question you
-- wrote down in notebook 01. The aggregation should happen here, in SQL,
-- not in pandas after a SELECT *.
-- =========================================================================


-- =========================================================================
-- Q1 | Of the listings that should have a tourist licence (stays under 31 nights), how many show one?
-- =========================================================================
-- Hypothesis: Most short-stay listings show a HUTB licence, but a sizeable minority (10-20%) show no licence at all.
-- Finding:    75.1% (7,336) show a HUTB licence and 14.7% (1,435) show no licence information. The remaining 10% declare an exemption
--             or another code (mostly hotels and hostels).
-- @query: q1
SELECT ls.status_code,
       COUNT(*) AS n_listings,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM listings WHERE minimum_nights < 31), 1) AS pct_listings
FROM listings AS l
JOIN licence_status AS ls ON l.licence_status_id = ls.licence_status_id
WHERE l.minimum_nights < 31
GROUP BY ls.status_code
ORDER BY n_listings DESC;

-- =========================================================================
-- Q2 | In which districts is the share of short-stay listings with no licence highest?
-- =========================================================================
-- Hypothesis: The share is highest in outer, residential districts and
--             lowest in the tourist centre, which is more inspected.
-- Finding: Partly supported. The highest shares are in outer districts:
--             Nou Barris (27.4%), Horta-Guinardó (26.9%), Sant Andreu (26.8%).
--             But the centre is not low: Ciutat Vella is 4th (21.5%, above
--             the 14.7% city average). Share and count point to different
--             places: Eixample has the lowest share (10.4%) but the most
--             unlicensed listings (441), and Ciutat Vella has 349, more than
--             the top three districts combined (116).
-- @query: q2
SELECT d.district_name,
       COUNT(*) AS n_short_stay,
       SUM(CASE WHEN ls.status_code = 'missing' THEN 1 ELSE 0 END) AS n_no_licence,
       ROUND(100.0 * SUM(CASE WHEN ls.status_code = 'missing' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_no_licence
FROM listings AS l
JOIN neighbourhoods AS n  ON l.neighbourhood_id  = n.neighbourhood_id
JOIN districts AS d       ON n.district_id       = d.district_id
JOIN licence_status AS ls ON l.licence_status_id = ls.licence_status_id
WHERE l.minimum_nights < 31
GROUP BY d.district_name
HAVING COUNT(*) >= 100
ORDER BY pct_no_licence DESC;

-- =========================================================================
-- Q3 | Which types of listing are most often unlicensed?
-- =========================================================================
-- Hypothesis: Unlicensed short-stay listings are mostly private rooms,
--             because the HUTB licence covers entire homes.
-- Finding: Strongly supported. 46.4% of short-stay private rooms show no
--             licence, against 4.1% of entire homes: over 10 times as likely.
--             Private rooms are only 25% of short-stay listings (2,458 of
--             9,765) but 79.4% of all unlicensed ones (1,140 of 1,435).
--             Likely reason: rooms fall outside the HUTB licence system, so
--             the gap is structural rather than hidden non-compliance.
-- @query: q3
SELECT l.room_type,
       COUNT(*) AS n_short_stay,
       SUM(CASE WHEN ls.status_code = 'missing' THEN 1 ELSE 0 END) AS n_no_licence,
       ROUND(100.0 * SUM(CASE WHEN ls.status_code = 'missing' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_no_licence,
       ROUND(100.0 * SUM(CASE WHEN ls.status_code = 'missing' THEN 1 ELSE 0 END)
             / (SELECT COUNT(*)
                FROM listings
                WHERE minimum_nights < 31
                  AND licence_status_id = (SELECT licence_status_id
                                           FROM licence_status
                                           WHERE status_code = 'missing')), 1) AS pct_of_all_unlicensed
FROM listings AS l
JOIN licence_status AS ls ON l.licence_status_id = ls.licence_status_id
WHERE l.minimum_nights < 31
GROUP BY l.room_type
ORDER BY n_no_licence DESC;

-- =========================================================================
-- Q4 | Are the listings with no licence actually being rented?
-- =========================================================================
-- Hypothesis: Most unlicensed short-stay listings are inactive (no review
--             in the last 12 months), so the real problem is smaller than
--             the headline count.
-- Finding: Supported. Only 25.6% of unlicensed short-stay listings were
--             active (367 of 1,435), against 83.8% of licensed ones. The
--             unlicensed listings are 14.7% of short-stay supply (Q1) but
--             only about 5% of active short-stay listings (367 of 7,212).
--             Caveat: activity is measured through reviews, so 25.6% is a
--             lower bound; the gap with licensed listings is too large to
--             be explained by that alone.
-- @query: q4
SELECT ls.status_code,
       COUNT(*) AS n_short_stay,
       SUM(CASE WHEN l.listing_id IN (SELECT listing_id
                                      FROM reviews
                                      WHERE review_date BETWEEN '2025-06-24' AND '2026-06-24')
                THEN 1 ELSE 0 END) AS n_active,
       ROUND(100.0 * SUM(CASE WHEN l.listing_id IN (SELECT listing_id
                                                    FROM reviews
                                                    WHERE review_date BETWEEN '2025-06-24' AND '2026-06-24')
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_active
FROM listings AS l
JOIN licence_status AS ls ON l.licence_status_id = ls.licence_status_id
WHERE l.minimum_nights < 31
GROUP BY ls.status_code
ORDER BY pct_active DESC;

-- =========================================================================
-- Q5 | Do listings that show a licence number use a number of their own?
-- =========================================================================
-- Hypothesis: A licence belongs to one dwelling, so most numbers should
--             appear on a single listing; shared numbers should be rare.
-- Finding: Not as rare as expected. 581 licence numbers appear on more
--             than one listing, covering 1,743 of the 7,406 listings that
--             show a HUTB number (23.5%). 410 numbers are shared by
--             different hosts (1,250 listings, 16.9%). Some are clearly
--             invented: HUTB-000000 (35 listings, 15 hosts), HUTB-246789
--             (26 listings, 12 hosts), HUTB-123456 (11 listings, 11 hosts).
--             So the 75.1% "licensed" share in Q1 is an upper bound.
--             Caveat: numbers cannot be checked against the official
--             register, and some sharing may be legitimate.

-- 5a: the ten most shared numbers
-- @query: q5a
SELECT licence_number,
       COUNT(*) AS n_listings,
       COUNT(DISTINCT host_id) AS n_hosts
FROM listings
WHERE licence_number IS NOT NULL
GROUP BY licence_number
HAVING COUNT(*) > 1
ORDER BY n_listings DESC
LIMIT 10;


-- 5b: overall size of the issue
-- @query: q5b
SELECT COUNT(*) AS n_shared_numbers,
       SUM(n_listings) AS n_listings_on_shared,
       SUM(CASE WHEN n_hosts > 1 THEN 1 ELSE 0 END) AS n_numbers_multi_host,
       SUM(CASE WHEN n_hosts > 1 THEN n_listings ELSE 0 END) AS n_listings_multi_host
FROM (SELECT licence_number,
             COUNT(*) AS n_listings,
             COUNT(DISTINCT host_id) AS n_hosts
      FROM listings
      WHERE licence_number IS NOT NULL
      GROUP BY licence_number
      HAVING COUNT(*) > 1) AS shared;

-- =========================================================================
-- Q6 | How big is the mid-term (31+ nights) segment, and how do its hosts
--      set their minimum stay?
-- =========================================================================
-- Hypothesis: the mid-term segment is a large share of the market, and its
--             minimum stays cluster just above the 31-night threshold rather
--             than being spread over genuinely long stays.
-- Finding: Supported. 36.1% of all listings (5,527 of 15,293) require
--             31+ nights. Of these, 95.7% set the minimum at exactly 31
--             (2,644) or 32 nights (2,647); only 4.3% ask for more than 32.
--             The minimum is set to clear the threshold, not to target long
--             stays. One listing has no minimum recorded and is labelled
--             'unknown' rather than assigned to a segment.

-- 6a: size of each segment
-- @query: q6a
SELECT CASE
           WHEN minimum_nights IS NULL THEN 'unknown'
           WHEN minimum_nights >= 31 THEN 'mid_term'
           ELSE 'short_stay'
       END AS segment,
       COUNT(*) AS n_listings,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM listings), 1) AS pct_listings
FROM listings
GROUP BY segment
ORDER BY n_listings DESC;

-- 6b: how the minimum stay is set within the mid-term segment
-- @query: q6b
SELECT CASE
           WHEN minimum_nights = 31 THEN '31 nights'
           WHEN minimum_nights = 32 THEN '32 nights'
           WHEN minimum_nights <= 90 THEN '33-90 nights'
           ELSE '91+ nights'
       END AS min_stay_band,
       COUNT(*) AS n_listings,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM listings WHERE minimum_nights >= 31), 1) AS pct_of_mid_term
FROM listings
WHERE minimum_nights >= 31
GROUP BY min_stay_band
ORDER BY MIN(minimum_nights);

-- =========================================================================
-- Q7 | Are mid-term listings in the same districts as licensed tourist
--      flats, or somewhere else?
-- =========================================================================
-- Hypothesis: The mid-term segment is concentrated in the same central
--             districts as licensed short-stay listings, rather than in
--             residential districts.
-- Finding: Supported overall, with an important split. Ciutat Vella and
--             Eixample hold 58.4% of mid-term listings, almost the same as
--             their 59.7% of licensed short-stay listings. But in Ciutat
--             Vella half of all listings (49.9%) are mid-term, and it has
--             29.3% of the segment against 14.3% of licensed short stays;
--             Eixample is the opposite (29.1% vs 45.4%). Exception:
--             Sarrià-Sant Gervasi, a residential district, has the highest
--             mid-term share (51.0%), which fits genuine long stays better.
-- @query: q7
SELECT d.district_name,
       COUNT(*) AS n_listings,
       SUM(CASE WHEN l.minimum_nights >= 31 THEN 1 ELSE 0 END) AS n_mid_term,
       ROUND(100.0 * SUM(CASE WHEN l.minimum_nights >= 31 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_mid_term_in_district,
       ROUND(100.0 * SUM(CASE WHEN l.minimum_nights >= 31 THEN 1 ELSE 0 END)
             / (SELECT COUNT(*) FROM listings WHERE minimum_nights >= 31), 1) AS pct_of_all_mid_term,
       ROUND(100.0 * SUM(CASE WHEN l.minimum_nights < 31 AND ls.status_code = 'hutb_licence' THEN 1 ELSE 0 END)
             / (SELECT COUNT(*)
                FROM listings
                WHERE minimum_nights < 31
                  AND licence_status_id = (SELECT licence_status_id
                                           FROM licence_status
                                           WHERE status_code = 'hutb_licence')), 1) AS pct_of_all_licensed_short
FROM listings AS l
JOIN neighbourhoods AS n  ON l.neighbourhood_id  = n.neighbourhood_id
JOIN districts AS d       ON n.district_id       = d.district_id
JOIN licence_status AS ls ON l.licence_status_id = ls.licence_status_id
GROUP BY d.district_name
ORDER BY n_mid_term DESC;

-- =========================================================================
-- Q8 | How do mid-term listings compare with licensed short-stay listings
--      on price, size and activity?
-- =========================================================================
-- Hypothesis: Mid-term listings are cheaper per guest and less active than
--             licensed short-stay listings.
-- Finding: Cheaper: strongly supported. Mid-term listings average
--             EUR 35.7 per guest per night, about half of licensed short
--             stays (EUR 73.9). Not an outlier effect: 44.5% of mid-term
--             listings cost under EUR 30 per guest, against 2.4% of licensed
--             short stays (8b). Medians computed in pandas agree
--             (EUR 31.8 vs EUR 65.6). Mid-term listings are also smaller
--             (2.9 vs 4.7 guests), hence the per-guest comparison.
--             Less active: supported with a strong caveat. 44.6% active vs
--             83.8%, and 64 vs 117 estimated nights booked, but both are
--             based on reviews, and longer stays generate fewer reviews.
--             Ratings are similar (4.58 vs 4.64).
--             Price bands (EUR 30, EUR 60) chosen to split the two segments'
--             typical values; they are not an industry standard.
-- 8a: side-by-side comparison
-- @query: q8a
SELECT CASE WHEN l.minimum_nights >= 31 THEN 'mid_term'
            ELSE 'licensed_short_stay' END AS segment,
       COUNT(*) AS n_listings,
       COUNT(l.price_eur) AS n_with_price,
       ROUND(AVG(l.accommodates), 1) AS avg_guests,
       ROUND(AVG(l.price_eur / l.accommodates), 1) AS avg_price_per_guest,
       ROUND(AVG(l.estimated_occupancy_l365d), 0) AS avg_nights_booked,
       ROUND(100.0 * SUM(CASE WHEN l.listing_id IN (SELECT listing_id
                                                    FROM reviews
                                                    WHERE review_date BETWEEN '2025-06-24' AND '2026-06-24')
                              THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_active,
       ROUND(AVG(l.review_scores_rating), 2) AS avg_rating
FROM listings AS l
JOIN licence_status AS ls ON l.licence_status_id = ls.licence_status_id
WHERE l.minimum_nights >= 31
   OR (l.minimum_nights < 31 AND ls.status_code = 'hutb_licence')
GROUP BY segment;

-- 8b: price-per-guest bands (robust to outliers)
-- @query: q8b
SELECT CASE WHEN l.price_eur / l.accommodates < 30 THEN 'under 30'
            WHEN l.price_eur / l.accommodates < 60 THEN '30 to 60'
            ELSE '60 or more' END AS price_per_guest_band,
       SUM(CASE WHEN l.minimum_nights < 31 THEN 1 ELSE 0 END) AS n_licensed_short_stay,
       SUM(CASE WHEN l.minimum_nights >= 31 THEN 1 ELSE 0 END) AS n_mid_term
FROM listings AS l
JOIN licence_status AS ls ON l.licence_status_id = ls.licence_status_id
WHERE (l.minimum_nights >= 31
       OR (l.minimum_nights < 31 AND ls.status_code = 'hutb_licence'))
  AND l.price_eur IS NOT NULL
GROUP BY price_per_guest_band
ORDER BY MIN(l.price_eur / l.accommodates);
