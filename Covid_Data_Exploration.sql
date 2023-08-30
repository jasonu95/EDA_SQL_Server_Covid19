-- Data tomada de https://ourworldindata.org/covid-deaths
--revisando la importación de xslx a sql server
SELECT *
FROM PortfolioProject_covid..CovidDeaths
ORDER BY 3,4;

SELECT *
FROM PortfolioProject_covid..CovidVaccinations
ORDER BY 3,4;
--de ahora en adelante se debe de agregar continent is not null

--Cambiando algunos tipos de datos
SELECT *  
FROM PortfolioProject_covid..CovidDeaths 
WHERE Try_Cast(population As bigint) Is Null And population Is Not Null;
--tuve que cambiar los valores primero a float y luego a bigint porque los valores traían un .0 al final de cada valor (lo hice en la herramienta de table designer)


--***********************************EXPLORACIÓN POR PAIS***********************************
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject_covid..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2;

--Total cases vs total_deaths: Muestra la tasa de mortalidad del covid una vez contraes la enfermedad.
SELECT location, date, total_cases, total_deaths, (CAST(total_deaths as FLOAT)/total_cases)*100 AS MortalityRate
FROM PortfolioProject_covid..CovidDeaths
WHERE location	like 'Costa%' AND continent IS NOT NULL --Filtrado para Costa Rica
ORDER BY 2;

--Total cases vs population: Muestra al porcentaje de la población que se contagio de covid
SELECT location, date, population, total_cases, (CAST(total_cases as FLOAT)/population)*100 AS PercentPopulationInfected
FROM PortfolioProject_covid..CovidDeaths
WHERE location	like 'Costa%' AND continent IS NOT NULL
ORDER BY 2;

--Buscando paises con tasa de infección más alta en comparación con su población
SELECT location, population, MAX(total_cases) AS HighestInfectionCount, MAX((CAST(total_cases as FLOAT)/population)*100) AS PercentPopulationInfected
FROM PortfolioProject_covid..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY 4 DESC;

--Mostrar paises con mayor conteo de muertes
SELECT location, MAX(total_deaths) AS HighestDeathCount
FROM PortfolioProject_covid..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY HighestDeathCount DESC;

--Mostrar paises con mayor conteo de muertes en comparación a su población
SELECT location, population, MAX(total_deaths) AS HighestDeathCount, MAX((CAST(total_deaths as FLOAT)/population)*100) AS DeathRate
FROM PortfolioProject_covid..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY DeathRate DESC;


--***********************************EXPLORACIÓN DE DATOS POR CONTINENTE***********************************
--Mostrar continentes con mayor conteo de muertes
SELECT continent, SUM(HighestDeathCount) AS DeathCount
FROM 
	(SELECT continent,location, MAX(total_deaths) AS HighestDeathCount
	FROM PortfolioProject_covid..CovidDeaths
	WHERE continent IS NOT NULL
	GROUP BY continent, location) AS CountryDeathCount
GROUP BY continent
ORDER BY DeathCount DESC;


--Mostrar continentes con mayor conteo de muertes (Es la misma información arrojada por la consulta anterior pero utilizando los totales que ya venian en los datos, me funciona como una manera de revisar la integridad de los datos)
SELECT location, MAX(total_deaths) AS HighestDeathCount
FROM PortfolioProject_covid..CovidDeaths
WHERE continent IS NULL
GROUP BY location
ORDER BY HighestDeathCount DESC;



--***********************************EXPLORACIÓN DE DATOS GLOBAL***********************************
--Total cases vs total_deaths: Muestra la tasa de mortalidad por covid del una vez contraes la enfermedad.
SELECT date, SUM(total_deaths) AS TotalDeaths, SUM(total_cases) AS TotalCases, (CAST(SUM(total_deaths) as FLOAT)/SUM(total_cases))*100 AS MortalityRate
FROM PortfolioProject_covid..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1;
--datos de enero 2020 parecen poco fiables: hay más registros de muertes que de casos (supongo que se debe a que apenas se iniciaba a tomar en serio al virus)

--La siguiente consutla aclara que son algunos paises de Africa los responsables de reportar más muertes que casos en enero 2020
--Muchos paises de africas sufren de hambre o guerras, por lo que organisarse y buscar rescursos para hacer test debió de haber sido un desafío.
SELECT date, location, total_cases, total_deaths
FROM PortfolioProject_covid..CovidDeaths
WHERE total_deaths > total_cases AND continent IS NULL AND MONTH(date)=1 AND YEAR(date)=2020
ORDER BY 2,1;

--Total cases vs total_deaths: Muestra la tasa de mortalidad por covid del una vez contraes la enfermedad. (esta vez sin enero 2020)
SELECT date, SUM(total_deaths) AS TotalDeaths, SUM(total_cases) AS TotalCases, (CAST(SUM(total_deaths) as FLOAT)/SUM(total_cases))*100 AS MortalityRate
FROM PortfolioProject_covid..CovidDeaths
WHERE continent IS NOT NULL AND date >= '2020-02-01'
GROUP BY date
ORDER BY 1;



--Observando Total Population vs Vaccinations
SELECT CD.continent, CD.location, CD.date, CD.population, CV.new_vaccinations
FROM PortfolioProject_covid..CovidDeaths CD
JOIN PortfolioProject_covid..CovidVaccinations CV
	ON CD.location = CV.location
	AND CD.date = CV.date
WHERE CD.continent IS NOT NULL
ORDER BY 2,3;

SELECT CD.continent, CD.location, CD.date, CD.population, /*CV.new_vaccinations,*/ CV.new_vaccinations_smoothed, /*CV.total_vaccinations,*/
		SUM(CV.new_vaccinations_smoothed) OVER (PARTITION BY	CD.location ORDER BY CD.location, CD.date) AS TotalPeopleVaccinated
		--, (TotalPeopleVaccinated / population) * 100
FROM PortfolioProject_covid..CovidDeaths CD
JOIN PortfolioProject_covid..CovidVaccinations CV
	ON CD.location = CV.location
	AND CD.date = CV.date
WHERE CD.continent IS NOT NULL
ORDER BY 2,3;

--Usando una CTE
WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, People_Vaccinated)
AS (
	SELECT CD.continent, CD.location, CD.date, CD.population, /*CV.new_vaccinations,*/ CV.new_vaccinations_smoothed, /*CV.total_vaccinations,*/
			SUM(CV.new_vaccinations_smoothed) OVER (PARTITION BY	CD.location ORDER BY CD.location, CD.date) AS TotalPeopleVaccinated
			--, (TotalPeopleVaccinated / population) * 100
	FROM PortfolioProject_covid..CovidDeaths CD
	JOIN PortfolioProject_covid..CovidVaccinations CV
		ON CD.location = CV.location
		AND CD.date = CV.date
	WHERE CD.continent IS NOT NULL
)
SELECT *, (People_Vaccinated / Population) * 100 AS Population_Vaccinated
FROM PopvsVac --Population_Vaccinated puede superar el 100% porque (deacuerdo a la metadata) la columna "new_vaccinations" cuenta le numero de dosis de la vacuna aplicadas, no a las personas.
--Tabla "temporal"

DROP TABLE IF EXISTS #PercentPupulationVaccinated --por si hay que volver a correr esta consulta

CREATE TABLE #PercentPupulationVaccinated (
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population bigint,
New_Vaccinations bigint,
People_Vaccinated float
)

INSERT INTO #PercentPupulationVaccinated
SELECT CD.continent, CD.location, CD.date, CD.population, /*CV.new_vaccinations,*/ CV.new_vaccinations_smoothed, /*CV.total_vaccinations,*/
		SUM(CV.new_vaccinations_smoothed) OVER (PARTITION BY CD.location ORDER BY CD.location, CD.date) AS TotalPeopleVaccinated
		--, (TotalPeopleVaccinated / population) * 100
FROM PortfolioProject_covid..CovidDeaths CD
JOIN PortfolioProject_covid..CovidVaccinations CV
	ON CD.location = CV.location
	AND CD.date = CV.date
WHERE CD.continent IS NOT NULL
ORDER BY 2,3;

SELECT *, (People_Vaccinated / Population) * 100 AS Population_Vaccinated
FROM #PercentPupulationVaccinated


--Creando un view para posibles visualizaciones
CREATE VIEW PercentPupulationVaccinated AS
SELECT CD.continent, CD.location, CD.date, CD.population, /*CV.new_vaccinations,*/ CV.new_vaccinations_smoothed, /*CV.total_vaccinations,*/
		SUM(CV.new_vaccinations_smoothed) OVER (PARTITION BY CD.location ORDER BY CD.location, CD.date) AS TotalPeopleVaccinated
		--, (TotalPeopleVaccinated / population) * 100
FROM PortfolioProject_covid..CovidDeaths CD
JOIN PortfolioProject_covid..CovidVaccinations CV
	ON CD.location = CV.location
	AND CD.date = CV.date
WHERE CD.continent IS NOT NULL