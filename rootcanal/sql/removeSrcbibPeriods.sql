# these commands remove extraneous periods from the end of certain fields (author, year, imprint, title) in the srcbib table
# while preserving necessary ones (following middle initials, in 'n.d.', in 'Jr.', etc.)

UPDATE srcbib SET author = TRIM(TRAILING '.' FROM author) WHERE author RLIKE '\\.$' AND BINARY author NOT RLIKE '[A-Z]\\.$' AND BINARY author NOT RLIKE ' eds?\\.$' AND BINARY author NOT RLIKE ' al\\.$' AND BINARY author NOT RLIKE 'Sc\\.$' AND BINARY author NOT RLIKE 'Jr\\.$';
UPDATE srcbib SET year = TRIM(TRAILING '.' FROM year) WHERE year RLIKE '\\.$' AND BINARY year NOT RLIKE 'd\\.$';
UPDATE srcbib SET imprint = TRIM(TRAILING '.' FROM imprint) WHERE imprint RLIKE '\\.$' AND BINARY imprint NOT RLIKE 'Co\\.$' AND BINARY imprint NOT RLIKE 'ms\\.$';
UPDATE srcbib SET title = TRIM(TRAILING '.' FROM title) WHERE title RLIKE '\\.$' AND title NOT RLIKE '\\.\\.\\.$' AND BINARY title NOT RLIKE ' ms\\.$' AND BINARY title NOT RLIKE 'R\\.$';