
--- Part 1. Observe life expectancy dataset, restructure the data and EA 
--- Part 2. join other datasets to prepare for later tableau visualisations 



--- Part 1 

--- Observe the data 

SELECT * 
FROM life_exp;


--- Rename country column 

EXEC sp_rename 'life_exp.[Country Name]', 'country';


--- Pivot the data longer 

drop table if exists lep;

SELECT country, life_expectancy, year into lep
FROM
(
  SELECT *
  FROM life_exp
) AS lexp
UNPIVOT 
(
  life_expectancy FOR year IN ([1960],[1961],[1962],[1963],[1964],[1965],[1966],[1967],[1968],[1969],
  [1970],[1971],[1972],[1973],[1974],[1975],[1976],[1977],[1978],[1979],
  [1980],[1981],[1982],[1983],[1984],[1985],[1986],[1987],[1988],[1989],
  [1990],[1991],[1992],[1993],[1994],[1995],[1996],[1997],[1998],[1999],
  [2000],[2001],[2002],[2003],[2004],[2005],[2006],[2007],[2008],[2009],
  [2010],[2011],[2012],[2013],[2014],[2015],[2016],[2017],[2018],[2019],
  [2020])
) AS lep;



--- Observe pivoted data where the year is 2020 

SELECT * 
FROM lep
WHERE year = 2020;


--- Check for duplicates 

SELECT Country, year, life_expectancy, COUNT(*) AS CNT
FROM lep
GROUP BY Country, year, life_expectancy
HAVING COUNT(*) > 1;

--- There appears to be a duplicate of every entry 

--- Add id column 

ALTER TABLE lep
ADD ID INT IDENTITY(1,1);

SELECT * from lep;


--- Data without duplicates 

SELECT *
FROM lep
WHERE ID NOT IN
    (SELECT MAX(ID)
        FROM lep
        GROUP BY  Country, year);


--- Delete duplicates 

DELETE FROM lep
WHERE ID NOT IN
    (SELECT MAX(ID)
        FROM lep
        GROUP BY  Country, year);



--- Total life expectancy rates in Ireland over time 

SELECT year, life_expectancy 
FROM lep
WHERE Country = 'Ireland';


--- 2020 life expectancy of countries, order highest to lowest  

SELECT Country, life_expectancy
FROM lep 
WHERE year = 2020 
ORDER by -life_expectancy;


--- 2020 life expectancy of countries, order lowest to highest 

SELECT Country, life_expectancy 
FROM lep 
WHERE year = 2020 
ORDER by life_expectancy;



--- Use lag to show yearly percentage change of life expectancy in Ireland

drop table if exists Life_Expectancy_Ireland;

SELECT Country, year, life_expectancy, 100-((lag(life_expectancy)over (order by year) / life_expectancy)*100) as percentage_change
INTO Life_Expectancy_Ireland
FROM lep
WHERE Country = 'Ireland';

SELECT * from Life_Expectancy_Ireland;


--- Years life expectancy decreased from previous year in Ireland 

SELECT * 
FROM Life_Expectancy_Ireland
WHERE percentage_change < 0;




--- Part 2 

--- We will now join several other tables to the lep data in preparation for tableau visualisations 

--- In the "pop" data, "Turkey" is spelt "Turkiye". We will rename it so it matches our previous data set 

select * from pop where country like 'Turk%';

UPDATE pop
SET Country = replace (Country, 'Turkiye', 'Turkey');


--- Join pop and lep tables 

drop table if exists join_1;

select 
    A.Country, B.Country_code, A.year, B.population, A.life_expectancy
into 
    join_1 
from 
    lep A
left join 
    pop B on (B.Country = A.Country and B.year = A.Year)


select * from join_1;



--- Join spending 

SELECT *
FROM health_spending;


--- FIlter total and US dollars per capita 

drop table if exists health_spending_2;

SELECT Location, TIME, Value 
INTO health_spending_2
FROM health_spending 
WHERE SUBJECT = 'TOT' and MEASURE = 'USD_CAP';


--- Rename columns 

EXEC sp_rename 'health_spending_2.Value', 'Spending';

EXEC sp_rename 'health_spending_2.LOCATION', 'Country';

EXEC sp_rename 'health_spending_2.TIME', 'year';


SELECT * 
FROM health_spending_2


drop table if exists join_2;
select 
    A.Country, A.Country_code, A.year, A.population, A.life_expectancy, B.Spending
into 
    join_2
from 
    join_1 A
left join 
    health_spending_2 B on (B.Country = A.Country_code and B.year = A.Year);


select * from join_2;

--- There are many NULLs in some if the datasets that we will join due to the nature of the data.
--- The United States is included in some capacity in all datasets so we will use it to make sure our joins are working.

select * from join_2
where Country = 'United States';



--- Create two obesity datasets 

select * from obesity;


--- 1. female 

drop table if exists obesity_female ;

select Country_Name, Year, Value
into obesity_female
FROM obesity 
WHERE Disaggregation = 'female'
order by Country_Name, Year;

EXEC sp_rename 'obesity_female.Value', 'obesity_female';

SELECT * from obesity_female;


--- 2. male 

drop table if exists obesity_male ;

select Country_Name, Year, Value
into obesity_male
FROM obesity 
WHERE Disaggregation = 'male'
order by Country_Name, Year;

EXEC sp_rename 'obesity_male.Value', 'obesity_male';

SELECT * from obesity_male;



--- Join obesity datasets 

--- 1. female 

drop table if exists join_3;
select 
    A.Country, A.Country_code, A.year, A.population, A.life_expectancy, A.Spending, B.obesity_female
into 
    join_3
from 
    join_2 A
left join 
    obesity_female B on (B.Country_Name = A.Country and B.Year = A.year);


select * 
from join_3
where Country = 'United States';



--- 2. Male 

drop table if exists join_4;
select 
    A.Country, A.Country_code, A.year, A.population, A.life_expectancy, A.Spending, A.obesity_female, B.obesity_male
into 
    join_4
from 
    join_3 A
left join 
    obesity_male B on (B.Country_Name = A.Country and B.Year = A.year);


select * 
from join_4
where Country = 'United States';




--- Create smoke dataset 

drop table if exists smoke ;

select Country, Year, Value
into smoke
FROM Daily_smokers  
WHERE SUBJECT = 'TOT';

EXEC sp_rename 'smoke.Value', 'Daily_smokers';


--- Join smoke table 

SELECT * 
FROM smoke; 


drop table if exists join_5;
select 
    A.Country, A.Country_code, A.year, A.population, A.life_expectancy, A.Spending, A.obesity_female, A.obesity_male, B.Daily_smokers
into 
    join_5
from 
    join_4 A
left JOIN smoke B on (B.Country = A.Country_code and B.Year = A.year);


select * 
from join_5 
where Country = 'United States';




--- Vaccination data 

SELECT * 
FROM Child_vaccination;


--- Create 2 vaccination datasets 

--- 1. DTP table 

drop table if exists child_vaccination_DTP ;

select Country, Year, Vaccination_rate
into child_vaccination_DTP
FROM Child_vaccination  
WHERE Vaccine = 'DTP';


EXEC sp_rename 'child_vaccination_DTP.Vaccination_rate', 'DTP_Vaccination_rate';

SELECT * 
FROM child_vaccination_DTP;


--- 2. Measles table 

drop table if exists child_vaccination_Measles ;

select Country, Year, Vaccination_rate
into child_vaccination_Measles
FROM Child_vaccination  
WHERE Vaccine = 'MEASLES';

EXEC sp_rename 'child_vaccination_Measles.Vaccination_rate', 'Measles_Vaccination_rate';

SELECT * 
FROM child_vaccination_Measles;


--- Join 2 vaccincation tables 

--- 1. Join DTP table 


drop table if exists join_6;
select 
    A.Country, A.Country_code, A.year, A.population, A.life_expectancy, A.Spending, A.obesity_female, A.obesity_male, A.Daily_smokers, B.DTP_Vaccination_rate
into 
    join_6
from 
    join_5 A
left JOIN child_vaccination_DTP B on (B.Country = A.Country_code and B.Year = A.year);


select * 
from join_6
where Country = 'United States';



--- 2. Join  Measles table 


drop table if exists Tableau_table;
select 
    A.Country, A.Country_code, A.year, A.population, A.life_expectancy, A.Spending, A.obesity_female, A.obesity_male,
	A.Daily_smokers, A.DTP_Vaccination_rate, B.Measles_Vaccination_rate
into 
    Tableau_table
from 
    join_6 A
left JOIN child_vaccination_Measles B on (B.Country = A.Country_code and B.Year = A.year);


SELECT * 
FROM Tableau_table
WHERE Country = 'United States'; 

-- We will proceed to create visualisations with this data in tableau





