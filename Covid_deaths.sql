USE Portfolio_Project1;
alter table Portfolio_Project1..Covid_Deaths alter column total_deaths float null;
alter table Portfolio_Project1..Covid_Deaths alter column total_cases float null;
alter table Portfolio_Project1..Covid_Deaths alter column new_cases float null;
alter table Portfolio_Project1..Covid_Deaths alter column new_deaths float null;
alter table Portfolio_Project1..Covid_Vaccinations alter column new_vaccinations float null;
UPDATE dbo.Covid_Deaths SET continent = NULL WHERE continent = '';

----XXXX----
-- for tableau

-- 1. 

Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From dbo.Covid_Deaths
--Where location like '%states%'
where continent is not null 
--Group By date
order by 1,2

-- Just a double check based off the data provided
-- numbers are extremely close so we will keep them - The Second includes "International"  Location


--Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
--From PortfolioProject..CovidDeaths
----Where location like '%states%'
--where location = 'World'
----Group By date
--order by 1,2


-- 2. 

-- We take these out as they are not inluded in the above queries and want to stay consistent
-- European Union is part of Europe

Select location, SUM(cast(new_deaths as int)) as TotalDeathCount
From dbo.Covid_Deaths
--Where location like '%states%'
Where continent is null 
and location not like '%income%'
and location not in ('World', 'European Union', 'International')
Group by location
order by TotalDeathCount desc


-- 3.

Select Location, Population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From dbo.Covid_Deaths
--Where location like '%states%'
Group by Location, Population
order by PercentPopulationInfected desc


-- 4.


Select Location, Population,date, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From dbo.Covid_Deaths
--Where location like '%states%'
Group by Location, Population, date
order by PercentPopulationInfected desc


--SELECT * FROM Portfolio_Project1.dbo.Covid_Deaths
--WHERE continent IS NOT NULL
--order by 3,4;

--SELECT * FROM Portfolio_Project1.dbo.Covid_Vaccinations
--order by 3,4;

----XXXX----

-- likelihood of dying
create view Likelihood_of_dying as
select 
	location, 
	date,
	total_deaths,
	total_cases, 
Case 
	when total_cases=0 then null
	Else (total_deaths/total_cases)*100
End AS Deathpercentage
FROM Portfolio_Project1..Covid_Deaths
WHERE continent IS NOT NULL
--order by 1;

----XXXX----
 
-- total cases vs population
create view CasesVSPopulation as
select 
	location,
	date,
	total_cases,
	population,
Case 
	when total_cases=0 then null
	Else (total_cases/population)*100
End AS Casepercentage
FROM dbo.Covid_Deaths
WHERE continent IS NOT NULL
--order by 1;

----XXXX----

--highest infection rates around the world
create view Infection_rates as
select
	location,
	population,
	MAX(total_cases) as max_case,
	MAX((total_cases/population))*100 AS max_infection_rate
from dbo.Covid_Deaths
WHERE continent IS NOT NULL
group by location, population
--order by 4 desc;

----XXXX----

-- highest death rates around the world
create view Death_rates as
select
	location,
	population,
	MAX(total_deaths) AS max_deaths,
	MAX((total_deaths/population)) as max_death_rate
from dbo.Covid_Deaths
WHERE continent IS NOT NULL
group by location, population
--order by 3 desc;

----XXXX----

--highest death rates by continent
create view Continent_death_rates as
select
	location,
	MAX(total_deaths) AS max_deaths,
	MAX((total_deaths/population)) as max_death_rate
from dbo.Covid_Deaths
WHERE continent IS NULL
group by location
--order by 3 desc;

----XXXX----

-- highest death rates and infection rate based on income
create view Death_rates_based_on_income as
select
	location,
	MAX(total_deaths) AS max_deaths,
	MAX((total_deaths/population)) as max_death_rate
from dbo.Covid_Deaths 
WHERE location like '%income%'
group by location
--order by 3 desc;

----XXXX----

-- highest infection rates based on income
create view Infection_rates_based_on_income as
select
	location,
	MAX(total_cases) as max_case,
	MAX((total_cases/population))*100 AS max_infection_rate
from dbo.Covid_Deaths 
WHERE location like '%income%'
group by location
--order by 3 desc;

----XXXX----

-- global numbers
create view Global_numbers as
select
	date,
	SUM(new_cases) AS CasesPerDay,
	SUM(new_deaths) AS DeathsPerDay,
case
	when SUM(new_cases) = 0 then null
	else (SUM(new_deaths)/SUM(new_cases))*100
end as Death_Percentage
from dbo.Covid_Deaths
where continent IS NOT NULL
group by date
--order by YEAR(date),MONTH(date),DAY(date)


----XXXX----

-- join both tables for more queries
select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	SUM(vac.new_vaccinations) OVER (partition by dea.location order by dea.location, dea.date)  AS rolling_vaccinations
	--(rolling_vaccinations/population)*100 AS PopvsVac 
	-- USE CTE or temp table for the above
	from dbo.Covid_Deaths as dea
	join dbo.Covid_Vaccinations as vac
		on dea.location = vac.location
		and dea.date = vac.date
where dea.continent IS NOT NULL 
order by 2,3;


-- with CTE
with PopvsVac(continent, location, date, population, new_vaccinations, rolling_vaccinations)
as
(
select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	SUM(vac.new_vaccinations) OVER (partition by dea.location order by dea.location, dea.date)  AS rolling_vaccinations
	--(rolling_vaccinations/population)*100 AS PopvsVac
	from dbo.Covid_Deaths as dea
	join dbo.Covid_Vaccinations as vac
		on dea.location = vac.location
		and dea.date = vac.date
where dea.continent IS NOT NULL 
--order by 2,3
)
select *, (rolling_vaccinations/population)*100 AS PercentageVaccinations
from PopvsVac

-- Temp Table

Drop Table if exists #PercentagePopulationVaccinated
-- using this line we can constanly update the table according to requirements

create Table #PercentagePopulationVaccinated
(
	continent nvarchar(255),
	location nvarchar(255),
	date dateTime,
	population numeric,
	new_vaccinations numeric,
	rolling_vaccinations numeric
)
Insert into #PercentagePopulationVaccinated
select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	SUM(vac.new_vaccinations) OVER (partition by dea.location order by dea.location, dea.date)  AS rolling_vaccinations
	--(rolling_vaccinations/population)*100 AS PopvsVac
	from dbo.Covid_Deaths as dea
	join dbo.Covid_Vaccinations as vac
		on dea.location = vac.location
		and dea.date = vac.date
where dea.continent IS NOT NULL 
--order by 2,3

select *, (rolling_vaccinations/population)*100 AS PercentageVaccinations
from #PercentagePopulationVaccinated

----XXXX----