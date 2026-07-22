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

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: prevent_financial_audit_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_financial_audit_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION '% is append-only', TG_TABLE_NAME
    USING ERRCODE = 'integrity_constraint_violation';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_operations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_operations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id bigint,
    context_id bigint,
    request_id character varying,
    source character varying NOT NULL,
    result character varying NOT NULL,
    parent_operation_id uuid,
    rollback_of_operation_id uuid,
    selected_version_id bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT audit_operations_metadata_size CHECK ((octet_length((metadata)::text) <= 16384)),
    CONSTRAINT audit_operations_result CHECK (((result)::text = ANY (ARRAY[('committed'::character varying)::text, ('rejected'::character varying)::text, ('failed'::character varying)::text]))),
    CONSTRAINT audit_operations_source CHECK (((source)::text = ANY (ARRAY[('web'::character varying)::text, ('api'::character varying)::text, ('actionable_message'::character varying)::text, ('admin_repair'::character varying)::text, ('import'::character varying)::text, ('background_job'::character varying)::text, ('rollback'::character varying)::text, ('console'::character varying)::text, ('unknown'::character varying)::text])))
);


--
-- Name: audit_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_versions (
    id bigint NOT NULL,
    item_type character varying NOT NULL,
    item_subtype character varying,
    item_id bigint NOT NULL,
    event character varying NOT NULL,
    whodunnit character varying,
    object jsonb,
    object_changes jsonb,
    operation_id uuid NOT NULL,
    owner_id bigint NOT NULL,
    context_id bigint,
    mutation_source character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT audit_versions_event CHECK (((event)::text = ANY (ARRAY[('create'::character varying)::text, ('update'::character varying)::text, ('destroy'::character varying)::text]))),
    CONSTRAINT audit_versions_metadata_size CHECK ((octet_length((metadata)::text) <= 16384)),
    CONSTRAINT audit_versions_mutation_source CHECK (((mutation_source)::text = ANY (ARRAY[('web'::character varying)::text, ('api'::character varying)::text, ('actionable_message'::character varying)::text, ('admin_repair'::character varying)::text, ('import'::character varying)::text, ('background_job'::character varying)::text, ('rollback'::character varying)::text, ('console'::character varying)::text, ('unknown'::character varying)::text, ('shared_sync'::character varying)::text, ('projection_sync'::character varying)::text, ('reference_sync'::character varying)::text, ('piggy_bank_sync'::character varying)::text, ('balance_recalculation'::character varying)::text]))),
    CONSTRAINT audit_versions_object_changes_size CHECK (((object_changes IS NULL) OR (octet_length((object_changes)::text) <= 262144))),
    CONSTRAINT audit_versions_object_size CHECK (((object IS NULL) OR (octet_length((object)::text) <= 262144)))
);


--
-- Name: audit_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_versions_id_seq OWNED BY public.audit_versions.id;


--
-- Name: banks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.banks (
    id bigint NOT NULL,
    bank_code integer NOT NULL,
    bank_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: banks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.banks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: banks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.banks_id_seq OWNED BY public.banks.id;


--
-- Name: budget_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budget_categories (
    id bigint NOT NULL,
    budget_id bigint NOT NULL,
    category_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: budget_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.budget_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: budget_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.budget_categories_id_seq OWNED BY public.budget_categories.id;


--
-- Name: budget_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budget_entities (
    id bigint NOT NULL,
    budget_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    entity_id bigint NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: budget_entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.budget_entities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: budget_entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.budget_entities_id_seq OWNED BY public.budget_entities.id;


--
-- Name: budgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budgets (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    balance integer,
    context_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    description character varying NOT NULL,
    first_installment_only boolean DEFAULT false NOT NULL,
    inclusive boolean DEFAULT false NOT NULL,
    month integer NOT NULL,
    order_id integer,
    remaining_value integer NOT NULL,
    starting_value integer NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    value integer NOT NULL,
    year integer NOT NULL
);


--
-- Name: budgets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.budgets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: budgets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.budgets_id_seq OWNED BY public.budgets.id;


--
-- Name: card_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.card_transactions (
    id bigint NOT NULL,
    advance_cash_transaction_id bigint,
    card_installments_count integer DEFAULT 0 NOT NULL,
    comment text,
    context_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    date timestamp(6) without time zone NOT NULL,
    description character varying NOT NULL,
    imported boolean DEFAULT false,
    month integer NOT NULL,
    paid boolean DEFAULT false,
    price integer NOT NULL,
    reference_transactable_id bigint,
    reference_transactable_type character varying,
    starting_price integer NOT NULL,
    subscription_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_card_id bigint NOT NULL,
    user_id bigint NOT NULL,
    year integer NOT NULL
);


--
-- Name: card_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.card_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.card_transactions_id_seq OWNED BY public.card_transactions.id;


--
-- Name: cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cards (
    id bigint NOT NULL,
    bank_id bigint NOT NULL,
    card_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- Name: cash_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cash_transactions (
    id bigint NOT NULL,
    cash_installments_count integer DEFAULT 0 NOT NULL,
    cash_transaction_type character varying,
    comment text,
    context_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    date timestamp(6) without time zone NOT NULL,
    description character varying NOT NULL,
    friend_notification_intent character varying,
    imported boolean DEFAULT false,
    investment_type_id bigint,
    month integer NOT NULL,
    paid boolean DEFAULT false,
    price integer NOT NULL,
    reference_transactable_id bigint,
    reference_transactable_type character varying,
    starting_price integer NOT NULL,
    subscription_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_bank_account_id bigint,
    user_card_id bigint,
    user_id bigint NOT NULL,
    year integer NOT NULL
);


--
-- Name: cash_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cash_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cash_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cash_transactions_id_seq OWNED BY public.cash_transactions.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    built_in boolean DEFAULT false NOT NULL,
    card_transactions_count integer DEFAULT 0 NOT NULL,
    card_transactions_total integer DEFAULT 0 NOT NULL,
    cash_transactions_count integer DEFAULT 0 NOT NULL,
    cash_transactions_total integer DEFAULT 0 NOT NULL,
    category_name character varying NOT NULL,
    colour character varying DEFAULT 'white'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: category_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_transactions (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    transactable_id bigint NOT NULL,
    transactable_type character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_transactions_id_seq OWNED BY public.category_transactions.id;


--
-- Name: contexts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contexts (
    id bigint NOT NULL,
    archived_at timestamp(6) without time zone,
    cloned_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    description text,
    main boolean DEFAULT false NOT NULL,
    name character varying NOT NULL,
    scenario_key character varying,
    source_context_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: contexts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contexts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contexts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contexts_id_seq OWNED BY public.contexts.id;


--
-- Name: conversation_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_participants (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: conversation_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conversation_participants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversation_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conversation_participants_id_seq OWNED BY public.conversation_participants.id;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    kind character varying DEFAULT 'human'::character varying NOT NULL,
    scenario_key character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conversations_id_seq OWNED BY public.conversations.id;


--
-- Name: entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entities (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    avatar_name character varying DEFAULT 'people/0.png'::character varying NOT NULL,
    built_in boolean DEFAULT false NOT NULL,
    card_transactions_count integer DEFAULT 0 NOT NULL,
    card_transactions_total integer DEFAULT 0 NOT NULL,
    cash_transactions_count integer DEFAULT 0 NOT NULL,
    cash_transactions_total integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    entity_name character varying NOT NULL,
    entity_user_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entities_id_seq OWNED BY public.entities.id;


--
-- Name: entity_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_transactions (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    entity_id bigint NOT NULL,
    exchanges_count integer DEFAULT 0 NOT NULL,
    is_payer boolean DEFAULT false NOT NULL,
    loan_return_percentage numeric(10,4) DEFAULT 100.0 NOT NULL,
    price integer DEFAULT 0 NOT NULL,
    price_to_be_returned integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    transactable_id bigint NOT NULL,
    transactable_type character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: entity_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entity_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entity_transactions_id_seq OWNED BY public.entity_transactions.id;


--
-- Name: exchanges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exchanges (
    id bigint NOT NULL,
    bound_type character varying DEFAULT 'standalone'::character varying NOT NULL,
    cash_transaction_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    date timestamp(6) without time zone NOT NULL,
    entity_transaction_id bigint NOT NULL,
    exchange_type integer DEFAULT 0 NOT NULL,
    exchanges_count integer DEFAULT 0 NOT NULL,
    month integer NOT NULL,
    number integer DEFAULT 1 NOT NULL,
    price integer NOT NULL,
    starting_price integer NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    year integer NOT NULL
);


--
-- Name: exchanges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.exchanges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: exchanges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.exchanges_id_seq OWNED BY public.exchanges.id;


--
-- Name: finance_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_subscriptions (
    id bigint NOT NULL,
    card_transactions_count integer DEFAULT 0 NOT NULL,
    cash_transactions_count integer DEFAULT 0 NOT NULL,
    comment text,
    context_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    description character varying NOT NULL,
    price integer DEFAULT 0 NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: finance_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_subscriptions_id_seq OWNED BY public.finance_subscriptions.id;


--
-- Name: installments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.installments (
    id bigint NOT NULL,
    balance integer,
    card_installments_count integer DEFAULT 0,
    card_transaction_id bigint,
    cash_installments_count integer DEFAULT 0,
    cash_transaction_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    date timestamp(6) without time zone NOT NULL,
    date_month integer GENERATED ALWAYS AS (EXTRACT(month FROM date)) STORED NOT NULL,
    date_year integer GENERATED ALWAYS AS (EXTRACT(year FROM date)) STORED NOT NULL,
    installment_type character varying NOT NULL,
    month integer NOT NULL,
    number integer NOT NULL,
    order_id integer,
    paid boolean DEFAULT false,
    price integer NOT NULL,
    starting_price integer NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    year integer NOT NULL
);


--
-- Name: installments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.installments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: installments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.installments_id_seq OWNED BY public.installments.id;


--
-- Name: investment_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.investment_types (
    id bigint NOT NULL,
    built_in boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    investment_type_code character varying,
    investment_type_name_fallback character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: investment_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.investment_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: investment_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.investment_types_id_seq OWNED BY public.investment_types.id;


--
-- Name: investments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.investments (
    id bigint NOT NULL,
    cash_transaction_id bigint,
    context_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    date timestamp(6) without time zone NOT NULL,
    description character varying,
    investment_type_id bigint NOT NULL,
    month integer NOT NULL,
    piggy_bank_return_cash_transaction_id bigint,
    price integer NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_bank_account_id bigint NOT NULL,
    user_id bigint NOT NULL,
    year integer NOT NULL
);


--
-- Name: investments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.investments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: investments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.investments_id_seq OWNED BY public.investments.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    applied_at timestamp(6) without time zone,
    body text,
    conversation_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    headers text,
    read_at timestamp(6) without time zone,
    reference_transactable_id bigint,
    reference_transactable_type character varying,
    superseded_by_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    audit_operation_id uuid
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: piggy_banks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.piggy_banks (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    return_cash_transaction_id bigint,
    return_date timestamp(6) without time zone NOT NULL,
    return_price integer NOT NULL,
    source_cash_transaction_id bigint NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT piggy_banks_return_price_positive CHECK ((return_price > 0))
);


--
-- Name: piggy_banks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.piggy_banks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: piggy_banks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.piggy_banks_id_seq OWNED BY public.piggy_banks.id;


--
-- Name: references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."references" (
    id bigint NOT NULL,
    context_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    month integer NOT NULL,
    reference_closing_date date NOT NULL,
    reference_date date NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_card_id bigint NOT NULL,
    year integer NOT NULL
);


--
-- Name: references_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.references_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: references_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.references_id_seq OWNED BY public."references".id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id bigint NOT NULL,
    auth text,
    created_at timestamp(6) without time zone NOT NULL,
    endpoint text,
    p256dh text,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscriptions_id_seq OWNED BY public.subscriptions.id;


--
-- Name: user_bank_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_bank_accounts (
    id bigint NOT NULL,
    account_number integer,
    active boolean DEFAULT true NOT NULL,
    agency_number integer,
    balance integer DEFAULT 0 NOT NULL,
    bank_id bigint NOT NULL,
    cash_transactions_count integer DEFAULT 0 NOT NULL,
    cash_transactions_total integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_bank_account_name character varying,
    user_id bigint NOT NULL
);


--
-- Name: user_bank_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_bank_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_bank_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_bank_accounts_id_seq OWNED BY public.user_bank_accounts.id;


--
-- Name: user_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_cards (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    card_id bigint NOT NULL,
    card_transactions_count integer DEFAULT 0 NOT NULL,
    card_transactions_total integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    credit_limit integer NOT NULL,
    days_until_due_date integer NOT NULL,
    due_date_day integer DEFAULT 1 NOT NULL,
    min_spend integer NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_card_name character varying NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_cards_id_seq OWNED BY public.user_cards.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    admin boolean DEFAULT false NOT NULL,
    confirmation_sent_at timestamp(6) without time zone,
    confirmation_token character varying,
    confirmed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    locale character varying NOT NULL,
    remember_created_at timestamp(6) without time zone,
    reset_password_sent_at timestamp(6) without time zone,
    reset_password_token character varying,
    unconfirmed_email character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: audit_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_versions ALTER COLUMN id SET DEFAULT nextval('public.audit_versions_id_seq'::regclass);


--
-- Name: banks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banks ALTER COLUMN id SET DEFAULT nextval('public.banks_id_seq'::regclass);


--
-- Name: budget_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_categories ALTER COLUMN id SET DEFAULT nextval('public.budget_categories_id_seq'::regclass);


--
-- Name: budget_entities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_entities ALTER COLUMN id SET DEFAULT nextval('public.budget_entities_id_seq'::regclass);


--
-- Name: budgets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets ALTER COLUMN id SET DEFAULT nextval('public.budgets_id_seq'::regclass);


--
-- Name: card_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_transactions ALTER COLUMN id SET DEFAULT nextval('public.card_transactions_id_seq'::regclass);


--
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- Name: cash_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_transactions ALTER COLUMN id SET DEFAULT nextval('public.cash_transactions_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: category_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_transactions ALTER COLUMN id SET DEFAULT nextval('public.category_transactions_id_seq'::regclass);


--
-- Name: contexts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contexts ALTER COLUMN id SET DEFAULT nextval('public.contexts_id_seq'::regclass);


--
-- Name: conversation_participants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants ALTER COLUMN id SET DEFAULT nextval('public.conversation_participants_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: entities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities ALTER COLUMN id SET DEFAULT nextval('public.entities_id_seq'::regclass);


--
-- Name: entity_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_transactions ALTER COLUMN id SET DEFAULT nextval('public.entity_transactions_id_seq'::regclass);


--
-- Name: exchanges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchanges ALTER COLUMN id SET DEFAULT nextval('public.exchanges_id_seq'::regclass);


--
-- Name: finance_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.finance_subscriptions_id_seq'::regclass);


--
-- Name: installments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments ALTER COLUMN id SET DEFAULT nextval('public.installments_id_seq'::regclass);


--
-- Name: investment_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_types ALTER COLUMN id SET DEFAULT nextval('public.investment_types_id_seq'::regclass);


--
-- Name: investments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investments ALTER COLUMN id SET DEFAULT nextval('public.investments_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: piggy_banks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.piggy_banks ALTER COLUMN id SET DEFAULT nextval('public.piggy_banks_id_seq'::regclass);


--
-- Name: references id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."references" ALTER COLUMN id SET DEFAULT nextval('public.references_id_seq'::regclass);


--
-- Name: subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions ALTER COLUMN id SET DEFAULT nextval('public.subscriptions_id_seq'::regclass);


--
-- Name: user_bank_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_bank_accounts ALTER COLUMN id SET DEFAULT nextval('public.user_bank_accounts_id_seq'::regclass);


--
-- Name: user_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_cards ALTER COLUMN id SET DEFAULT nextval('public.user_cards_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_operations audit_operations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_operations
    ADD CONSTRAINT audit_operations_pkey PRIMARY KEY (id);


--
-- Name: audit_versions audit_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_versions
    ADD CONSTRAINT audit_versions_pkey PRIMARY KEY (id);


--
-- Name: banks banks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banks
    ADD CONSTRAINT banks_pkey PRIMARY KEY (id);


--
-- Name: budget_categories budget_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_categories
    ADD CONSTRAINT budget_categories_pkey PRIMARY KEY (id);


--
-- Name: budget_entities budget_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_entities
    ADD CONSTRAINT budget_entities_pkey PRIMARY KEY (id);


--
-- Name: budgets budgets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT budgets_pkey PRIMARY KEY (id);


--
-- Name: card_transactions card_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_transactions
    ADD CONSTRAINT card_transactions_pkey PRIMARY KEY (id);


--
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- Name: cash_transactions cash_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_transactions
    ADD CONSTRAINT cash_transactions_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category_transactions category_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_transactions
    ADD CONSTRAINT category_transactions_pkey PRIMARY KEY (id);


--
-- Name: contexts contexts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contexts
    ADD CONSTRAINT contexts_pkey PRIMARY KEY (id);


--
-- Name: conversation_participants conversation_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants
    ADD CONSTRAINT conversation_participants_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: entity_transactions entity_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_transactions
    ADD CONSTRAINT entity_transactions_pkey PRIMARY KEY (id);


--
-- Name: exchanges exchanges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchanges
    ADD CONSTRAINT exchanges_pkey PRIMARY KEY (id);


--
-- Name: finance_subscriptions finance_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_subscriptions
    ADD CONSTRAINT finance_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: installments installments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT installments_pkey PRIMARY KEY (id);


--
-- Name: investment_types investment_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_types
    ADD CONSTRAINT investment_types_pkey PRIMARY KEY (id);


--
-- Name: investments investments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investments
    ADD CONSTRAINT investments_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: piggy_banks piggy_banks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.piggy_banks
    ADD CONSTRAINT piggy_banks_pkey PRIMARY KEY (id);


--
-- Name: references references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."references"
    ADD CONSTRAINT references_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: user_bank_accounts user_bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_bank_accounts
    ADD CONSTRAINT user_bank_accounts_pkey PRIMARY KEY (id);


--
-- Name: user_cards user_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_cards
    ADD CONSTRAINT user_cards_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_budgets_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_budgets_order_id ON public.budgets USING btree (order_id);


--
-- Name: idx_card_transactions_description_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_card_transactions_description_trgm ON public.card_transactions USING gin (description public.gin_trgm_ops);


--
-- Name: idx_card_transactions_price; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_card_transactions_price ON public.card_transactions USING btree (price);


--
-- Name: idx_installments_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_installments_order_id ON public.installments USING btree (order_id);


--
-- Name: idx_installments_price; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_installments_price ON public.installments USING btree (price);


--
-- Name: idx_installments_type_card_transaction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_installments_type_card_transaction ON public.installments USING btree (installment_type, card_transaction_id);


--
-- Name: idx_installments_type_cash_transaction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_installments_type_cash_transaction ON public.installments USING btree (installment_type, cash_transaction_id);


--
-- Name: idx_installments_year_month_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_installments_year_month_date ON public.installments USING btree (date_year, date_month, date);


--
-- Name: idx_references_context_user_card_month_year; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_references_context_user_card_month_year ON public."references" USING btree (context_id, user_card_id, month, year);


--
-- Name: idx_references_context_user_card_reference_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_references_context_user_card_reference_date ON public."references" USING btree (context_id, user_card_id, reference_date);


--
-- Name: index_audit_operations_on_actor_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_operations_on_actor_id_and_created_at ON public.audit_operations USING btree (actor_id, created_at);


--
-- Name: index_audit_operations_on_context_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_operations_on_context_id_and_created_at ON public.audit_operations USING btree (context_id, created_at);


--
-- Name: index_audit_operations_on_parent_operation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_operations_on_parent_operation_id ON public.audit_operations USING btree (parent_operation_id);


--
-- Name: index_audit_operations_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_operations_on_request_id ON public.audit_operations USING btree (request_id) WHERE (request_id IS NOT NULL);


--
-- Name: index_audit_operations_on_rollback_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_audit_operations_on_rollback_idempotency ON public.audit_operations USING btree (rollback_of_operation_id, actor_id, ((metadata ->> 'preview_digest'::text))) WHERE (((source)::text = 'rollback'::text) AND ((result)::text = 'committed'::text) AND (rollback_of_operation_id IS NOT NULL) AND (actor_id IS NOT NULL) AND (metadata ? 'preview_digest'::text));


--
-- Name: index_audit_operations_on_rollback_of_operation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_operations_on_rollback_of_operation_id ON public.audit_operations USING btree (rollback_of_operation_id);


--
-- Name: index_audit_operations_on_source_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_operations_on_source_and_created_at ON public.audit_operations USING btree (source, created_at);


--
-- Name: index_audit_versions_on_context_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_versions_on_context_id_and_created_at ON public.audit_versions USING btree (context_id, created_at);


--
-- Name: index_audit_versions_on_event_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_versions_on_event_and_created_at ON public.audit_versions USING btree (event, created_at);


--
-- Name: index_audit_versions_on_item_type_and_item_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_versions_on_item_type_and_item_id_and_created_at ON public.audit_versions USING btree (item_type, item_id, created_at);


--
-- Name: index_audit_versions_on_mutation_source_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_versions_on_mutation_source_and_created_at ON public.audit_versions USING btree (mutation_source, created_at);


--
-- Name: index_audit_versions_on_operation_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_versions_on_operation_id_and_id ON public.audit_versions USING btree (operation_id, id);


--
-- Name: index_audit_versions_on_owner_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_versions_on_owner_id_and_created_at ON public.audit_versions USING btree (owner_id, created_at);


--
-- Name: index_budget_categories_on_budget_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_budget_categories_on_budget_id ON public.budget_categories USING btree (budget_id);


--
-- Name: index_budget_categories_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_budget_categories_on_category_id ON public.budget_categories USING btree (category_id);


--
-- Name: index_budget_categories_on_composite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_budget_categories_on_composite_key ON public.budget_categories USING btree (budget_id, category_id);


--
-- Name: index_budget_entities_on_budget_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_budget_entities_on_budget_id ON public.budget_entities USING btree (budget_id);


--
-- Name: index_budget_entities_on_composite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_budget_entities_on_composite_key ON public.budget_entities USING btree (budget_id, entity_id);


--
-- Name: index_budget_entities_on_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_budget_entities_on_entity_id ON public.budget_entities USING btree (entity_id);


--
-- Name: index_budgets_on_context_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_budgets_on_context_id ON public.budgets USING btree (context_id);


--
-- Name: index_budgets_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_budgets_on_user_id ON public.budgets USING btree (user_id);


--
-- Name: index_card_transactions_on_advance_cash_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_transactions_on_advance_cash_transaction_id ON public.card_transactions USING btree (advance_cash_transaction_id);


--
-- Name: index_card_transactions_on_context_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_transactions_on_context_id ON public.card_transactions USING btree (context_id);


--
-- Name: index_card_transactions_on_reference_transactable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_transactions_on_reference_transactable ON public.card_transactions USING btree (reference_transactable_type, reference_transactable_id);


--
-- Name: index_card_transactions_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_transactions_on_subscription_id ON public.card_transactions USING btree (subscription_id);


--
-- Name: index_card_transactions_on_user_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_transactions_on_user_card_id ON public.card_transactions USING btree (user_card_id);


--
-- Name: index_card_transactions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_card_transactions_on_user_id ON public.card_transactions USING btree (user_id);


--
-- Name: index_cards_on_bank_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cards_on_bank_id ON public.cards USING btree (bank_id);


--
-- Name: index_cards_on_card_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cards_on_card_name ON public.cards USING btree (card_name);


--
-- Name: index_cash_transactions_on_context_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_transactions_on_context_id ON public.cash_transactions USING btree (context_id);


--
-- Name: index_cash_transactions_on_investment_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_transactions_on_investment_type_id ON public.cash_transactions USING btree (investment_type_id);


--
-- Name: index_cash_transactions_on_reference_transactable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_transactions_on_reference_transactable ON public.cash_transactions USING btree (reference_transactable_type, reference_transactable_id);


--
-- Name: index_cash_transactions_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_transactions_on_subscription_id ON public.cash_transactions USING btree (subscription_id);


--
-- Name: index_cash_transactions_on_user_bank_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_transactions_on_user_bank_account_id ON public.cash_transactions USING btree (user_bank_account_id);


--
-- Name: index_cash_transactions_on_user_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_transactions_on_user_card_id ON public.cash_transactions USING btree (user_card_id);


--
-- Name: index_cash_transactions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_transactions_on_user_id ON public.cash_transactions USING btree (user_id);


--
-- Name: index_categories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_user_id ON public.categories USING btree (user_id);


--
-- Name: index_category_name_on_composite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_name_on_composite_key ON public.categories USING btree (user_id, category_name);


--
-- Name: index_category_transactions_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_transactions_on_category_id ON public.category_transactions USING btree (category_id);


--
-- Name: index_category_transactions_on_composite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_transactions_on_composite_key ON public.category_transactions USING btree (category_id, transactable_type, transactable_id);


--
-- Name: index_category_transactions_on_transactable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_transactions_on_transactable ON public.category_transactions USING btree (transactable_type, transactable_id);


--
-- Name: index_contexts_on_scenario_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contexts_on_scenario_key ON public.contexts USING btree (scenario_key);


--
-- Name: index_contexts_on_source_context_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contexts_on_source_context_id ON public.contexts USING btree (source_context_id);


--
-- Name: index_contexts_on_user_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_contexts_on_user_and_name ON public.contexts USING btree (user_id, name);


--
-- Name: index_contexts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contexts_on_user_id ON public.contexts USING btree (user_id);


--
-- Name: index_contexts_on_user_id_where_main_true; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_contexts_on_user_id_where_main_true ON public.contexts USING btree (user_id) WHERE (main = true);


--
-- Name: index_conversation_participants_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversation_participants_on_conversation_id ON public.conversation_participants USING btree (conversation_id);


--
-- Name: index_conversation_participants_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversation_participants_on_user_id ON public.conversation_participants USING btree (user_id);


--
-- Name: index_conversations_on_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_kind ON public.conversations USING btree (kind);


--
-- Name: index_conversations_on_scenario_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_scenario_key ON public.conversations USING btree (scenario_key);


--
-- Name: index_entities_on_entity_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entities_on_entity_user_id ON public.entities USING btree (entity_user_id);


--
-- Name: index_entities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entities_on_user_id ON public.entities USING btree (user_id);


--
-- Name: index_entity_name_on_composite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entity_name_on_composite_key ON public.entities USING btree (user_id, entity_name);


--
-- Name: index_entity_transactions_on_composite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entity_transactions_on_composite_key ON public.entity_transactions USING btree (entity_id, transactable_type, transactable_id);


--
-- Name: index_entity_transactions_on_entity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entity_transactions_on_entity_id ON public.entity_transactions USING btree (entity_id);


--
-- Name: index_entity_transactions_on_transactable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entity_transactions_on_transactable ON public.entity_transactions USING btree (transactable_type, transactable_id);


--
-- Name: index_exchanges_on_cash_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exchanges_on_cash_transaction_id ON public.exchanges USING btree (cash_transaction_id);


--
-- Name: index_exchanges_on_entity_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exchanges_on_entity_transaction_id ON public.exchanges USING btree (entity_transaction_id);


--
-- Name: index_finance_subscriptions_on_context_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_subscriptions_on_context_id ON public.finance_subscriptions USING btree (context_id);


--
-- Name: index_finance_subscriptions_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_subscriptions_on_status ON public.finance_subscriptions USING btree (status);


--
-- Name: index_finance_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_subscriptions_on_user_id ON public.finance_subscriptions USING btree (user_id);


--
-- Name: index_installments_on_card_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_installments_on_card_transaction_id ON public.installments USING btree (card_transaction_id);


--
-- Name: index_installments_on_cash_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_installments_on_cash_transaction_id ON public.installments USING btree (cash_transaction_id);


--
-- Name: index_investment_types_on_built_in; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_investment_types_on_built_in ON public.investment_types USING btree (built_in);


--
-- Name: index_investment_types_on_investment_type_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_investment_types_on_investment_type_code ON public.investment_types USING btree (investment_type_code);


--
-- Name: index_investments_on_cash_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_investments_on_cash_transaction_id ON public.investments USING btree (cash_transaction_id);


--
-- Name: index_investments_on_context_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_investments_on_context_id ON public.investments USING btree (context_id);


--
-- Name: index_investments_on_investment_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_investments_on_investment_type_id ON public.investments USING btree (investment_type_id);


--
-- Name: index_investments_on_piggy_bank_return_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_investments_on_piggy_bank_return_id ON public.investments USING btree (piggy_bank_return_cash_transaction_id);


--
-- Name: index_investments_on_user_bank_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_investments_on_user_bank_account_id ON public.investments USING btree (user_bank_account_id);


--
-- Name: index_investments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_investments_on_user_id ON public.investments USING btree (user_id);


--
-- Name: index_messages_on_applied_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_applied_at ON public.messages USING btree (applied_at);


--
-- Name: index_messages_on_audit_operation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_audit_operation_id ON public.messages USING btree (audit_operation_id);


--
-- Name: index_messages_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_conversation_id ON public.messages USING btree (conversation_id);


--
-- Name: index_messages_on_reference_transactable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_reference_transactable ON public.messages USING btree (reference_transactable_type, reference_transactable_id);


--
-- Name: index_messages_on_superseded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_superseded_by_id ON public.messages USING btree (superseded_by_id);


--
-- Name: index_messages_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_user_id ON public.messages USING btree (user_id);


--
-- Name: index_piggy_banks_on_return_cash_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_piggy_banks_on_return_cash_transaction_id ON public.piggy_banks USING btree (return_cash_transaction_id);


--
-- Name: index_piggy_banks_on_source_cash_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_piggy_banks_on_source_cash_transaction_id ON public.piggy_banks USING btree (source_cash_transaction_id);


--
-- Name: index_reference_transactable_on_card_composite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reference_transactable_on_card_composite_key ON public.card_transactions USING btree (reference_transactable_type, reference_transactable_id);


--
-- Name: index_references_on_context_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_references_on_context_id ON public."references" USING btree (context_id);


--
-- Name: index_references_on_user_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_references_on_user_card_id ON public."references" USING btree (user_card_id);


--
-- Name: index_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_user_id ON public.subscriptions USING btree (user_id);


--
-- Name: index_user_bank_accounts_on_bank_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_bank_accounts_on_bank_id ON public.user_bank_accounts USING btree (bank_id);


--
-- Name: index_user_bank_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_bank_accounts_on_user_id ON public.user_bank_accounts USING btree (user_id);


--
-- Name: index_user_cards_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_cards_on_card_id ON public.user_cards USING btree (card_id);


--
-- Name: index_user_cards_on_on_composite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_cards_on_on_composite_key ON public.user_cards USING btree (user_id, card_id, user_card_name);


--
-- Name: index_user_cards_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_cards_on_user_id ON public.user_cards USING btree (user_id);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: audit_operations audit_operations_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_operations_append_only BEFORE DELETE OR UPDATE ON public.audit_operations FOR EACH ROW EXECUTE FUNCTION public.prevent_financial_audit_mutation();


--
-- Name: audit_versions audit_versions_append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_versions_append_only BEFORE DELETE OR UPDATE ON public.audit_versions FOR EACH ROW EXECUTE FUNCTION public.prevent_financial_audit_mutation();


--
-- Name: entity_transactions fk_rails_0454212ed0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_transactions
    ADD CONSTRAINT fk_rails_0454212ed0 FOREIGN KEY (entity_id) REFERENCES public.entities(id);


--
-- Name: investments fk_rails_07b456137c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investments
    ADD CONSTRAINT fk_rails_07b456137c FOREIGN KEY (context_id) REFERENCES public.contexts(id);


--
-- Name: messages fk_rails_0970dc7a45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_0970dc7a45 FOREIGN KEY (superseded_by_id) REFERENCES public.messages(id);


--
-- Name: card_transactions fk_rails_09e0bb8e5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_transactions
    ADD CONSTRAINT fk_rails_09e0bb8e5a FOREIGN KEY (user_card_id) REFERENCES public.user_cards(id);


--
-- Name: user_bank_accounts fk_rails_18fcb16a64; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_bank_accounts
    ADD CONSTRAINT fk_rails_18fcb16a64 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: installments fk_rails_215da81c23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT fk_rails_215da81c23 FOREIGN KEY (cash_transaction_id) REFERENCES public.cash_transactions(id);


--
-- Name: investments fk_rails_26317d56a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investments
    ADD CONSTRAINT fk_rails_26317d56a0 FOREIGN KEY (investment_type_id) REFERENCES public.investment_types(id);


--
-- Name: messages fk_rails_273a25a7a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_273a25a7a6 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: contexts fk_rails_2c076dcb91; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contexts
    ADD CONSTRAINT fk_rails_2c076dcb91 FOREIGN KEY (source_context_id) REFERENCES public.contexts(id);


--
-- Name: messages fk_rails_344cc91310; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_344cc91310 FOREIGN KEY (audit_operation_id) REFERENCES public.audit_operations(id) ON DELETE RESTRICT;


--
-- Name: installments fk_rails_38cdb1853d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT fk_rails_38cdb1853d FOREIGN KEY (card_transaction_id) REFERENCES public.card_transactions(id);


--
-- Name: conversation_participants fk_rails_39b25ba31e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants
    ADD CONSTRAINT fk_rails_39b25ba31e FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: cash_transactions fk_rails_39eafa9ae9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_transactions
    ADD CONSTRAINT fk_rails_39eafa9ae9 FOREIGN KEY (context_id) REFERENCES public.contexts(id);


--
-- Name: piggy_banks fk_rails_3cbdb79fba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.piggy_banks
    ADD CONSTRAINT fk_rails_3cbdb79fba FOREIGN KEY (source_cash_transaction_id) REFERENCES public.cash_transactions(id);


--
-- Name: card_transactions fk_rails_4334d3016d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_transactions
    ADD CONSTRAINT fk_rails_4334d3016d FOREIGN KEY (advance_cash_transaction_id) REFERENCES public.cash_transactions(id);


--
-- Name: cash_transactions fk_rails_4dd4ade1c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_transactions
    ADD CONSTRAINT fk_rails_4dd4ade1c3 FOREIGN KEY (user_bank_account_id) REFERENCES public.user_bank_accounts(id);


--
-- Name: finance_subscriptions fk_rails_51247cb7de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_subscriptions
    ADD CONSTRAINT fk_rails_51247cb7de FOREIGN KEY (context_id) REFERENCES public.contexts(id);


--
-- Name: cash_transactions fk_rails_53bdfba6b4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_transactions
    ADD CONSTRAINT fk_rails_53bdfba6b4 FOREIGN KEY (subscription_id) REFERENCES public.finance_subscriptions(id);


--
-- Name: investments fk_rails_59f93ac947; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investments
    ADD CONSTRAINT fk_rails_59f93ac947 FOREIGN KEY (user_bank_account_id) REFERENCES public.user_bank_accounts(id);


--
-- Name: budgets fk_rails_5d5e7d2349; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT fk_rails_5d5e7d2349 FOREIGN KEY (context_id) REFERENCES public.contexts(id);


--
-- Name: contexts fk_rails_6d2943ccf8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contexts
    ADD CONSTRAINT fk_rails_6d2943ccf8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: budget_entities fk_rails_70b492048f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_entities
    ADD CONSTRAINT fk_rails_70b492048f FOREIGN KEY (budget_id) REFERENCES public.budgets(id);


--
-- Name: entities fk_rails_71e168c975; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities
    ADD CONSTRAINT fk_rails_71e168c975 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: cards fk_rails_7a40ccfa76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT fk_rails_7a40ccfa76 FOREIGN KEY (bank_id) REFERENCES public.banks(id);


--
-- Name: finance_subscriptions fk_rails_7c4c169f47; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_subscriptions
    ADD CONSTRAINT fk_rails_7c4c169f47 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: messages fk_rails_7f927086d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_7f927086d2 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: investments fk_rails_8045d1b4d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investments
    ADD CONSTRAINT fk_rails_8045d1b4d1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: budget_categories fk_rails_83cbbb6bcc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_categories
    ADD CONSTRAINT fk_rails_83cbbb6bcc FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: entities fk_rails_8a74aa079f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities
    ADD CONSTRAINT fk_rails_8a74aa079f FOREIGN KEY (entity_user_id) REFERENCES public.users(id);


--
-- Name: references fk_rails_8b8b0cc8a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."references"
    ADD CONSTRAINT fk_rails_8b8b0cc8a4 FOREIGN KEY (context_id) REFERENCES public.contexts(id);


--
-- Name: subscriptions fk_rails_933bdff476; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_933bdff476 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: exchanges fk_rails_9a3f8bc972; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchanges
    ADD CONSTRAINT fk_rails_9a3f8bc972 FOREIGN KEY (cash_transaction_id) REFERENCES public.cash_transactions(id);


--
-- Name: card_transactions fk_rails_9bf4edc382; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_transactions
    ADD CONSTRAINT fk_rails_9bf4edc382 FOREIGN KEY (context_id) REFERENCES public.contexts(id);


--
-- Name: category_transactions fk_rails_a7bcc1e2b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_transactions
    ADD CONSTRAINT fk_rails_a7bcc1e2b0 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: budget_categories fk_rails_a928ada795; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_categories
    ADD CONSTRAINT fk_rails_a928ada795 FOREIGN KEY (budget_id) REFERENCES public.budgets(id);


--
-- Name: cash_transactions fk_rails_abaf8bf6ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_transactions
    ADD CONSTRAINT fk_rails_abaf8bf6ce FOREIGN KEY (user_card_id) REFERENCES public.user_cards(id);


--
-- Name: investments fk_rails_b8201a883b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investments
    ADD CONSTRAINT fk_rails_b8201a883b FOREIGN KEY (cash_transaction_id) REFERENCES public.cash_transactions(id);


--
-- Name: categories fk_rails_b8e2f7adfc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_b8e2f7adfc FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: investments fk_rails_ce357552d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investments
    ADD CONSTRAINT fk_rails_ce357552d4 FOREIGN KEY (piggy_bank_return_cash_transaction_id) REFERENCES public.cash_transactions(id);


--
-- Name: conversation_participants fk_rails_d4fdd4cae0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants
    ADD CONSTRAINT fk_rails_d4fdd4cae0 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: piggy_banks fk_rails_d56a7dffc1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.piggy_banks
    ADD CONSTRAINT fk_rails_d56a7dffc1 FOREIGN KEY (return_cash_transaction_id) REFERENCES public.cash_transactions(id);


--
-- Name: budget_entities fk_rails_d6cd0eb385; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_entities
    ADD CONSTRAINT fk_rails_d6cd0eb385 FOREIGN KEY (entity_id) REFERENCES public.entities(id);


--
-- Name: user_bank_accounts fk_rails_d7370eff8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_bank_accounts
    ADD CONSTRAINT fk_rails_d7370eff8f FOREIGN KEY (bank_id) REFERENCES public.banks(id);


--
-- Name: exchanges fk_rails_deee80dcd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchanges
    ADD CONSTRAINT fk_rails_deee80dcd2 FOREIGN KEY (entity_transaction_id) REFERENCES public.entity_transactions(id);


--
-- Name: budgets fk_rails_e708f32fd8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT fk_rails_e708f32fd8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: audit_versions fk_rails_ea7c85aae5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_versions
    ADD CONSTRAINT fk_rails_ea7c85aae5 FOREIGN KEY (operation_id) REFERENCES public.audit_operations(id) ON DELETE RESTRICT;


--
-- Name: card_transactions fk_rails_f1f6a75d66; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_transactions
    ADD CONSTRAINT fk_rails_f1f6a75d66 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: cash_transactions fk_rails_f2f83152e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_transactions
    ADD CONSTRAINT fk_rails_f2f83152e7 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: cash_transactions fk_rails_f423864408; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_transactions
    ADD CONSTRAINT fk_rails_f423864408 FOREIGN KEY (investment_type_id) REFERENCES public.investment_types(id);


--
-- Name: references fk_rails_f540ac2baf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."references"
    ADD CONSTRAINT fk_rails_f540ac2baf FOREIGN KEY (user_card_id) REFERENCES public.user_cards(id);


--
-- Name: card_transactions fk_rails_ff4db61853; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.card_transactions
    ADD CONSTRAINT fk_rails_ff4db61853 FOREIGN KEY (subscription_id) REFERENCES public.finance_subscriptions(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260722090000'),
('20260719091000'),
('20260719090000'),
('20260714100000'),
('20260712122000'),
('20260712121000'),
('20260712120000'),
('20260709130000'),
('20260709120000'),
('20260525000000'),
('20260503160000'),
('20260403153000'),
('20260324000000'),
('20260323133000'),
('20260323130000'),
('20260323005000'),
('20260323004000'),
('20260323003000'),
('20260323002000'),
('20260323001000'),
('20260323000000'),
('20260321183000'),
('20260321150000'),
('20260318000000'),
('20260314180000'),
('20260310120000'),
('20250904140109'),
('20250829000001'),
('20250303000001'),
('20250220000003'),
('20250220000002'),
('20250220000001'),
('20240501000003'),
('20240501000002'),
('20240501000001'),
('20231206000011'),
('20231206000010'),
('20231206000009'),
('20231206000008'),
('20231206000007'),
('20231206000006'),
('20231206000005'),
('20231206000004'),
('20231206000003'),
('20231206000002'),
('20231206000001'),
('20231200000003'),
('20231200000002'),
('20231200000001');

