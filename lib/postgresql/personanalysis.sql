-- Letterboxd analysis

-- Prerequisites:
-- The database must be setup for geoip using ip4r. See https://gist.github.com/karlvr/8ff1900bfc9cba36468640c26ae3b2bb

--
-- Schema
--

-- personcountrycode table
-- Contains a list of the countries that each person has accessed Letterboxd from,
-- and a count of the number of activity and sessions for each. We can use this data
-- to choose the most common country for a person.
create table if not exists personcountrycode (
	person int not null,
	countrycode varchar(2),
	count int not null,

	primary key(person, countrycode)
);

-- personanalysis table
-- Collects our latest analysis of each person. This is separate from the person table so we avoid any
-- locks while we're inserting into it. It does not maintain any foreign key references for that purpose.
create table if not exists personanalysis (
	person int not null primary key,
	countrycode varchar(2),
	earliestactivity date,
	latestactivity date,
	activitydays int,
	whencreated timestamp not null,
	latestsession date,
	sessiondays int,
	lifedays int,
	lifedaysrecent int
);

create index if not exists personanalysis_countrycode_ix on personanalysis(countrycode);

-- lb_retention function
-- Returns the percentage of users who used the site for minlifedays or longer, who registered in the given period.
create or replace function lb_retention(registered_start date, registered_end date, minlifedays int)
returns numeric
language sql
as 'select count(*) * 100.0 / (select count(*) from personanalysis where whencreated >= registered_start and whencreated < registered_end) from personanalysis where lifedays >= minlifedays and whencreated >= registered_start and whencreated < registered_end';

--
-- Update data
--

begin;

delete from personcountrycode;
insert into personcountrycode
select person, coalesce(geoip_country_code(remoteaddress), '??') as countrycode, sum(count) as count from (
select person, remoteaddress, sum(count) as count from (
select person, remoteaddress, count(*) as count from viewing where remoteaddress is not null group by person, remoteaddress
union all select person, remoteaddress, count(*) as count from viewingcomment where remoteaddress is not null group by person, remoteaddress
union all select person, remoteaddress, count(*) as count from filmlist where remoteaddress is not null group by person, remoteaddress
union all select person, remoteaddress, count(*) as count from filmlistcomment where remoteaddress is not null group by person, remoteaddress
union all select person, remoteaddress, count(*) as count from personsession where remoteaddress is not null group by person, remoteaddress
) as foo group by person, remoteaddress
) as bar 
group by person, countrycode;

-- personactivity temporary table
-- Contains a line for each day that each person has done some activity on the site,
-- and how many activities they done on that day.
create temp table personactivity as
select person, whenactivity, count(*) as count from (
select person, whencreated::date as whenactivity from viewing
union all select person, whencreated::date from viewingcomment
union all select person, whencreated::date from viewinglike
union all select person, whencreated::date from filmwatch 
union all select person, whencreated::date from filmlike 
union all select person, whencreated::date from filmrating 
union all select person, whencreated::date from filmlist 
union all select person, whencreated::date from filmlist 
union all select person, whencreated::date from filmlistcomment
union all select person, whencreated::date from filmlistlike
union all select person, whencreated::date from watchlist
) as foo group by person, whenactivity;

create index personactivity_person_ix on personactivity(person, whenactivity);

-- personsessionactivity temporary table
-- Contains a line for each day that each person has had sessions,
-- and how many sessions they had on that day.
create temp table personsessionactivity as
select person, whenactivity, count(*) as count from (
select person, whencreated::date as whenactivity from personsession
) as foo group by person, whenactivity;

create index personsessionactivity_person_ix on personsessionactivity(person, whenactivity);

-- delete from personanalysis;
insert into personanalysis (person, whencreated)
select id, whencreated from person
where not exists (select person from personanalysis where person=person.id);

-- Calculate most common country code for each person
update personanalysis set countrycode=(select countrycode from personcountrycode where personcountrycode.person=personanalysis.person and countrycode <> '??' order by count desc limit 1);

-- Now we can query out a summary of where our members come from:
-- select countrycode, count(*) from personanalysis group by 1 order by 2 desc;

-- Activity summary
update personanalysis set earliestactivity = (select min(whenactivity) from personactivity where person=personanalysis.person);
update personanalysis set latestactivity = (select max(whenactivity) from personactivity where person=personanalysis.person);
update personanalysis set activitydays = (select count(*) from personactivity where person=personanalysis.person);

-- Session summary
update personanalysis set latestsession = (select max(whenactivity) from personsessionactivity where personsessionactivity.person = personanalysis.person);
update personanalysis set sessiondays = (select count(*) from personsessionactivity where person=personanalysis.person);

-- Lifetime summary
update personanalysis set lifedays = latestactivity - earliestactivity;
update personanalysis set lifedaysrecent = lifedays where latestactivity >= now() - interval '1 year';

commit;
