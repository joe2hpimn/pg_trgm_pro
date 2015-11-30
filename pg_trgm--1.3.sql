/* contrib/pg_trgm/pg_trgm--1.3.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_trgm" to load this file. \quit

CREATE FUNCTION set_limit(float4)
RETURNS float4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT VOLATILE;

CREATE FUNCTION show_limit()
RETURNS float4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE;

CREATE FUNCTION show_trgm(text)
RETURNS _text
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE;

CREATE FUNCTION similarity(text,text)
RETURNS float4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE;

CREATE FUNCTION similarity_op(text,text)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE;  -- stable because depends on trgm_limit

CREATE OPERATOR % (
        LEFTARG = text,
        RIGHTARG = text,
        PROCEDURE = similarity_op,
        COMMUTATOR = '%',
        RESTRICT = contsel,
        JOIN = contjoinsel
);

CREATE FUNCTION substring_similarity(text,text)
RETURNS float4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE;

CREATE FUNCTION substring_similarity_op(text,text)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE;  -- stable because depends on trgm_limit

CREATE FUNCTION substring_similarity_commutator_op(text,text)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT STABLE;  -- stable because depends on trgm_limit

CREATE OPERATOR <% (
        LEFTARG = text,
        RIGHTARG = text,
        PROCEDURE = substring_similarity_op,
        COMMUTATOR = '%>',
        RESTRICT = contsel,
        JOIN = contjoinsel
);

CREATE OPERATOR %> (
        LEFTARG = text,
        RIGHTARG = text,
        PROCEDURE = substring_similarity_commutator_op,
        COMMUTATOR = '<%',
        RESTRICT = contsel,
        JOIN = contjoinsel
);

CREATE FUNCTION similarity_dist(text,text)
RETURNS float4
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE;

CREATE OPERATOR <-> (
        LEFTARG = text,
        RIGHTARG = text,
        PROCEDURE = similarity_dist,
        COMMUTATOR = '<->'
);

-- gist key
CREATE FUNCTION gtrgm_in(cstring)
RETURNS gtrgm
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE;

CREATE FUNCTION gtrgm_out(gtrgm)
RETURNS cstring
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT IMMUTABLE;

CREATE TYPE gtrgm (
        INTERNALLENGTH = -1,
        INPUT = gtrgm_in,
        OUTPUT = gtrgm_out
);

-- support functions for gist
CREATE FUNCTION gtrgm_consistent(internal,text,int,oid,internal)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gtrgm_distance(internal,text,int,oid)
RETURNS float8
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gtrgm_compress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gtrgm_decompress(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gtrgm_penalty(internal,internal,internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gtrgm_picksplit(internal, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gtrgm_union(bytea, internal)
RETURNS _int4
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gtrgm_same(gtrgm, gtrgm, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

-- create the operator class for gist
CREATE OPERATOR CLASS gist_trgm_ops
FOR TYPE text USING gist
AS
        OPERATOR        1       % (text, text),
        FUNCTION        1       gtrgm_consistent (internal, text, int, oid, internal),
        FUNCTION        2       gtrgm_union (bytea, internal),
        FUNCTION        3       gtrgm_compress (internal),
        FUNCTION        4       gtrgm_decompress (internal),
        FUNCTION        5       gtrgm_penalty (internal, internal, internal),
        FUNCTION        6       gtrgm_picksplit (internal, internal),
        FUNCTION        7       gtrgm_same (gtrgm, gtrgm, internal),
        STORAGE         gtrgm;

-- Add operators and support functions that are new in 9.1.  We do it like
-- this, leaving them "loose" in the operator family rather than bound into
-- the gist_trgm_ops opclass, because that's the only state that can be
-- reproduced during an upgrade from 9.0 (see pg_trgm--unpackaged--1.0.sql).

ALTER OPERATOR FAMILY gist_trgm_ops USING gist ADD
        OPERATOR        2       <-> (text, text) FOR ORDER BY pg_catalog.float_ops,
        OPERATOR        3       pg_catalog.~~ (text, text),
        OPERATOR        4       pg_catalog.~~* (text, text),
        FUNCTION        8 (text, text)  gtrgm_distance (internal, text, int, oid);

-- Add operators that are new in 9.3.

ALTER OPERATOR FAMILY gist_trgm_ops USING gist ADD
        OPERATOR        5       pg_catalog.~ (text, text),
        OPERATOR        6       pg_catalog.~* (text, text);

-- Add operators that are new in 9.6 (pg_trgm 1.3).

ALTER OPERATOR FAMILY gist_trgm_ops USING gist ADD
        OPERATOR        7       %> (text, text);

-- support functions for gin
CREATE FUNCTION gin_extract_value_trgm(text, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gin_extract_query_trgm(text, internal, int2, internal, internal, internal, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION gin_trgm_consistent(internal, int2, text, int4, internal, internal, internal, internal)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

-- create the operator class for gin
CREATE OPERATOR CLASS gin_trgm_ops
FOR TYPE text USING gin
AS
        OPERATOR        1       % (text, text),
        FUNCTION        1       btint4cmp (int4, int4),
        FUNCTION        2       gin_extract_value_trgm (text, internal),
        FUNCTION        3       gin_extract_query_trgm (text, internal, int2, internal, internal, internal, internal),
        FUNCTION        4       gin_trgm_consistent (internal, int2, text, int4, internal, internal, internal, internal),
        STORAGE         int4;

-- Add operators that are new in 9.1.

ALTER OPERATOR FAMILY gin_trgm_ops USING gin ADD
        OPERATOR        3       pg_catalog.~~ (text, text),
        OPERATOR        4       pg_catalog.~~* (text, text);

-- Add operators that are new in 9.3.

ALTER OPERATOR FAMILY gin_trgm_ops USING gin ADD
        OPERATOR        5       pg_catalog.~ (text, text),
        OPERATOR        6       pg_catalog.~* (text, text);

-- Add functions that are new in 9.6 (pg_trgm 1.2).

CREATE FUNCTION gin_trgm_triconsistent(internal, int2, text, int4, internal, internal, internal)
RETURNS "char"
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

ALTER OPERATOR FAMILY gin_trgm_ops USING gin ADD
        FUNCTION        6      (text,text) gin_trgm_triconsistent (internal, int2, text, int4, internal, internal, internal);

-- Add operators that are new in 9.6 (pg_trgm 1.3).

ALTER OPERATOR FAMILY gin_trgm_ops USING gin ADD
        OPERATOR        7       %> (text, text);