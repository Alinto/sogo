--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.24
-- Dumped by pg_dump version 9.6.24

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE ROLE sogobuild WITH
  SUPERUSER
  NOINHERIT
  CREATEDB
  CREATEROLE
  LOGIN
  PASSWORD 'sogo123';
CREATE ROLE sogo WITH
  SUPERUSER
  NOINHERIT
  CREATEDB
  CREATEROLE
  LOGIN
  PASSWORD 'sogo';
-- ALTER ROLE sogobuild WITH PASSWORD 'sogo123';
CREATE DATABASE sogo_integration_tests_auth with owner sogobuild;
-- CREATE USER sogo WITH PASSWORD 'sogo';
CREATE DATABASE sogo;
GRANT ALL PRIVILEGES ON DATABASE sogo TO sogo;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET default_tablespace = '';

SET default_with_oids = false;

\c sogo_integration_tests_auth

--
-- Name: sogoauth; Type: TABLE; Schema: public; Owner: sogobuild
--

CREATE TABLE public.sogoauth (
    c_uid character varying(255) NOT NULL,
    c_name character varying(255) NOT NULL,
    c_password character varying(255),
    c_cn character varying(255),
    mail character varying(255),
    kind character varying(255),
    multiplebookings integer
);


ALTER TABLE public.sogoauth OWNER TO sogobuild;

--
-- Data for Name: sogoauth; Type: TABLE DATA; Schema: public; Owner: sogobuild
--

COPY public.sogoauth (c_uid, c_name, c_password, c_cn, mail, kind, multiplebookings) FROM stdin;
sogo-tests-super	sogo-tests-super	sogo	sogo test super	sogo-tests-super@example.org	\N	\N
sogo-tests1	sogo-tests1	sogo	sogo One	sogo-tests1@example.org	\N	\N
sogo-tests2	sogo-tests2	sogo	sogo Two	sogo-tests2@example.org	\N	\N
sogo-tests3	sogo-tests3	sogo	sogo Three	sogo-tests3@example.org	\N	\N
res	res	sogo	Resource no overbook	res@example.org	location	1
res-nolimit	res-nolimit	sogo	Resource can overbook	res-nolimit@example.org	location	0
\.


--
-- Name: sogoauth sogoauth_c_name_key; Type: CONSTRAINT; Schema: public; Owner: sogobuild
--

ALTER TABLE ONLY public.sogoauth
    ADD CONSTRAINT sogoauth_c_name_key UNIQUE (c_name);


--
-- Name: sogoauth sogoauth_pkey; Type: CONSTRAINT; Schema: public; Owner: sogobuild
--

ALTER TABLE ONLY public.sogoauth
    ADD CONSTRAINT sogoauth_pkey PRIMARY KEY (c_uid);


--
-- PostgreSQL database dump complete
--