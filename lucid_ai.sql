-- LUCID AI complete PostgreSQL 16+ database schema
-- Generated from the supplied platform prompt and architecture image.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS auth_user;
CREATE SCHEMA IF NOT EXISTS world;
CREATE SCHEMA IF NOT EXISTS story;
CREATE SCHEMA IF NOT EXISTS npc;
CREATE SCHEMA IF NOT EXISTS ai;
CREATE SCHEMA IF NOT EXISTS media;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS combat;
CREATE SCHEMA IF NOT EXISTS progression;
CREATE SCHEMA IF NOT EXISTS economy;
CREATE SCHEMA IF NOT EXISTS politics;
CREATE SCHEMA IF NOT EXISTS weather;
CREATE SCHEMA IF NOT EXISTS transportation;
CREATE SCHEMA IF NOT EXISTS business;
CREATE SCHEMA IF NOT EXISTS guild;
CREATE SCHEMA IF NOT EXISTS marketplace;
CREATE SCHEMA IF NOT EXISTS creator;
CREATE SCHEMA IF NOT EXISTS journal;
CREATE SCHEMA IF NOT EXISTS recommendation;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS moderation;
CREATE SCHEMA IF NOT EXISTS notification;
CREATE SCHEMA IF NOT EXISTS multiplayer;
CREATE SCHEMA IF NOT EXISTS social;
CREATE SCHEMA IF NOT EXISTS subscription;
CREATE SCHEMA IF NOT EXISTS admin;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS history;
CREATE SCHEMA IF NOT EXISTS system;

CREATE TYPE system.entity_status AS ENUM ('draft','queued','active','inactive','published','archived','suspended','deleted');
CREATE TYPE system.visibility AS ENUM ('private','friends','party','guild','public','marketplace');
CREATE TYPE system.moderation_status AS ENUM ('unreviewed','pending','approved','rejected','flagged','blocked');
CREATE TYPE system.asset_kind AS ENUM ('world','story','quest','npc','item','image','voice','music','animation','video','theme','skin');
CREATE TYPE system.transaction_status AS ENUM ('draft','pending','authorized','paid','settled','refunded','cancelled','failed');
CREATE TYPE system.ai_request_status AS ENUM ('queued','running','succeeded','failed','cancelled','rate_limited');
CREATE TYPE system.notification_channel AS ENUM ('in_app','email','push','sms','webhook');
CREATE TYPE system.relationship_kind AS ENUM ('friend','enemy','family','spouse','child','guild','faction','mentor','rival','unknown');
CREATE DOMAIN system.email AS TEXT CHECK (VALUE ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$');
CREATE DOMAIN system.nonnegative_numeric AS NUMERIC(20,6) CHECK (VALUE >= 0);
CREATE DOMAIN system.score_100 AS NUMERIC(7,3) CHECK (VALUE BETWEEN -100 AND 100);

CREATE OR REPLACE FUNCTION system.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  NEW.version = COALESCE(OLD.version, 0) + 1;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION system.update_search_document()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.search_document := to_tsvector('english',
    COALESCE(NEW.name,'') || ' ' || COALESCE(NEW.slug,'') || ' ' ||
    COALESCE(NEW.description,'') || ' ' || COALESCE(NEW.metadata::text,''));
  RETURN NEW;
END;
$$;

CREATE TABLE auth_user.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email system.email NOT NULL UNIQUE,
  username TEXT NOT NULL UNIQUE,
  slug TEXT UNIQUE,
  password_hash TEXT,
  display_name TEXT NOT NULL,
  phone_number TEXT,
  avatar_url TEXT,
  bio TEXT,
  locale TEXT NOT NULL DEFAULT 'en',
  timezone TEXT NOT NULL DEFAULT 'UTC',
  email_verified_at TIMESTAMPTZ,
  phone_verified_at TIMESTAMPTZ,
  last_login_at TIMESTAMPTZ,
  is_premium BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB NOT NULL DEFAULT '{}',
  search_document TSVECTOR,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id),
  updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_users_email ON auth_user.users(email);
CREATE INDEX idx_users_username ON auth_user.users(username);
CREATE INDEX idx_users_metadata_gin ON auth_user.users USING gin(metadata);
CREATE INDEX idx_users_search_gin ON auth_user.users USING gin(search_document);
CREATE INDEX idx_users_active ON auth_user.users(id) WHERE deleted_at IS NULL;
CREATE TRIGGER trg_users_touch BEFORE UPDATE ON auth_user.users FOR EACH ROW EXECUTE FUNCTION system.touch_updated_at();
CREATE TRIGGER trg_users_search BEFORE INSERT OR UPDATE ON auth_user.users FOR EACH ROW EXECUTE FUNCTION system.update_search_document();

CREATE TABLE audit.audit_logs (
  id UUID DEFAULT gen_random_uuid(), occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_user_id UUID REFERENCES auth_user.users(id), action TEXT NOT NULL,
  schema_name TEXT NOT NULL, table_name TEXT NOT NULL, entity_id UUID,
  old_data JSONB, new_data JSONB, ip_address INET, user_agent TEXT, request_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ, PRIMARY KEY(id, occurred_at)
) PARTITION BY RANGE (occurred_at);
CREATE INDEX idx_audit_logs_actor ON audit.audit_logs(actor_user_id, occurred_at);
CREATE INDEX idx_audit_logs_entity ON audit.audit_logs(schema_name, table_name, entity_id);
CREATE INDEX idx_audit_logs_new_gin ON audit.audit_logs USING gin(new_data);

CREATE TABLE history.entity_history (
  id UUID DEFAULT gen_random_uuid(), changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  schema_name TEXT NOT NULL, table_name TEXT NOT NULL, entity_id UUID NOT NULL,
  entity_version BIGINT NOT NULL, changed_by UUID REFERENCES auth_user.users(id), row_data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ, PRIMARY KEY(id, changed_at)
) PARTITION BY RANGE (changed_at);
CREATE INDEX idx_history_entity ON history.entity_history(schema_name, table_name, entity_id);
CREATE INDEX idx_history_data_gin ON history.entity_history USING gin(row_data);

CREATE OR REPLACE FUNCTION audit.audit_row_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_actor UUID;
BEGIN
  v_actor := COALESCE(NEW.updated_by, OLD.updated_by, NEW.created_by, OLD.created_by);
  INSERT INTO audit.audit_logs(actor_user_id, action, schema_name, table_name, entity_id, old_data, new_data)
  VALUES (v_actor, TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME, COALESCE(NEW.id, OLD.id),
          CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
          CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END);
  IF TG_OP IN ('INSERT','UPDATE') THEN
    INSERT INTO history.entity_history(schema_name, table_name, entity_id, entity_version, changed_by, row_data)
    VALUES (TG_TABLE_SCHEMA, TG_TABLE_NAME, NEW.id, NEW.version, v_actor, to_jsonb(NEW));
    RETURN NEW;
  END IF;
  RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION system.create_lucid_entity_table(p_schema TEXT, p_table TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
  fq TEXT := format('%I.%I', p_schema, p_table);
  suffix TEXT := substr(md5(p_schema || '_' || p_table), 1, 18);
BEGIN
  EXECUTE format($SQL$
    CREATE TABLE IF NOT EXISTS %s (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_user_id UUID REFERENCES auth_user.users(id),
      related_user_id UUID REFERENCES auth_user.users(id),
      world_id UUID, story_id UUID, npc_id UUID, quest_id UUID, item_id UUID, asset_id UUID,
      parent_id UUID, source_entity_id UUID, target_entity_id UUID,
      name TEXT NOT NULL, slug TEXT, description TEXT,
      entity_type TEXT, category TEXT, status system.entity_status NOT NULL DEFAULT 'active',
      visibility system.visibility NOT NULL DEFAULT 'private',
      moderation_status system.moderation_status NOT NULL DEFAULT 'unreviewed',
      amount NUMERIC(20,6) NOT NULL DEFAULT 0, quantity NUMERIC(20,6) NOT NULL DEFAULT 0,
      score NUMERIC(12,6), rank_value BIGINT, level_value INT,
      starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ, published_at TIMESTAMPTZ,
      metadata JSONB NOT NULL DEFAULT '{}', settings JSONB NOT NULL DEFAULT '{}', stats JSONB NOT NULL DEFAULT '{}',
      embedding vector(1536), search_document TSVECTOR,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
      version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ,
      CONSTRAINT %I CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at)
    )
  $SQL$, fq, 'chk_' || suffix || '_time');
  EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS uq_%s_owner_slug ON %s(owner_user_id, slug) WHERE slug IS NOT NULL AND deleted_at IS NULL', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_owner ON %s(owner_user_id)', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_related_user ON %s(related_user_id)', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_world_story ON %s(world_id, story_id)', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_npc ON %s(npc_id)', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_status_created ON %s(status, created_at DESC) WHERE deleted_at IS NULL', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_metadata_gin ON %s USING gin(metadata)', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_settings_gin ON %s USING gin(settings)', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_stats_gin ON %s USING gin(stats)', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_search_gin ON %s USING gin(search_document)', suffix, fq);
  EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%s_embedding_hnsw ON %s USING hnsw (embedding vector_cosine_ops)', suffix, fq);
  EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_touch ON %s', suffix, fq);
  EXECUTE format('CREATE TRIGGER trg_%s_touch BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION system.touch_updated_at()', suffix, fq);
  EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_search ON %s', suffix, fq);
  EXECUTE format('CREATE TRIGGER trg_%s_search BEFORE INSERT OR UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION system.update_search_document()', suffix, fq);
  EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_audit ON %s', suffix, fq);
  EXECUTE format('CREATE TRIGGER trg_%s_audit AFTER INSERT OR UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION audit.audit_row_change()', suffix, fq);
  EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', fq);
  EXECUTE format('DROP POLICY IF EXISTS pol_%s_owner_select ON %s', suffix, fq);
  EXECUTE format('CREATE POLICY pol_%s_owner_select ON %s FOR SELECT USING (owner_user_id IS NULL OR owner_user_id::text = current_setting(''app.current_user_id'', true) OR visibility IN (''public'', ''marketplace''))', suffix, fq);
END;
$$;

SELECT system.create_lucid_entity_table('auth_user', 'profiles');
SELECT system.create_lucid_entity_table('auth_user', 'oauth_providers');
SELECT system.create_lucid_entity_table('auth_user', 'oauth_accounts');
SELECT system.create_lucid_entity_table('auth_user', 'refresh_tokens');
SELECT system.create_lucid_entity_table('auth_user', 'access_tokens');
SELECT system.create_lucid_entity_table('auth_user', 'roles');
SELECT system.create_lucid_entity_table('auth_user', 'permissions');
SELECT system.create_lucid_entity_table('auth_user', 'role_permissions');
SELECT system.create_lucid_entity_table('auth_user', 'user_roles');
SELECT system.create_lucid_entity_table('auth_user', 'devices');
SELECT system.create_lucid_entity_table('auth_user', 'device_sessions');
SELECT system.create_lucid_entity_table('auth_user', 'active_sessions');
SELECT system.create_lucid_entity_table('auth_user', 'security_logs');
SELECT system.create_lucid_entity_table('auth_user', 'login_history');
SELECT system.create_lucid_entity_table('auth_user', 'failed_login_attempts');
SELECT system.create_lucid_entity_table('auth_user', 'password_reset_tokens');
SELECT system.create_lucid_entity_table('auth_user', 'email_verification_tokens');
SELECT system.create_lucid_entity_table('auth_user', 'phone_verification');
SELECT system.create_lucid_entity_table('auth_user', 'two_factor_authentication');
SELECT system.create_lucid_entity_table('auth_user', 'recovery_codes');
SELECT system.create_lucid_entity_table('auth_user', 'privacy_settings');
SELECT system.create_lucid_entity_table('auth_user', 'notification_settings');
SELECT system.create_lucid_entity_table('auth_user', 'theme_settings');
SELECT system.create_lucid_entity_table('auth_user', 'language_settings');
SELECT system.create_lucid_entity_table('auth_user', 'accessibility_settings');
SELECT system.create_lucid_entity_table('auth_user', 'blocked_users');
SELECT system.create_lucid_entity_table('auth_user', 'friends');
SELECT system.create_lucid_entity_table('auth_user', 'followers');
SELECT system.create_lucid_entity_table('auth_user', 'following');
SELECT system.create_lucid_entity_table('auth_user', 'friend_requests');
SELECT system.create_lucid_entity_table('auth_user', 'user_preferences');
SELECT system.create_lucid_entity_table('auth_user', 'user_statistics');
SELECT system.create_lucid_entity_table('auth_user', 'user_badges');
SELECT system.create_lucid_entity_table('auth_user', 'premium_membership');
SELECT system.create_lucid_entity_table('auth_user', 'billing');
SELECT system.create_lucid_entity_table('auth_user', 'invoices');
SELECT system.create_lucid_entity_table('auth_user', 'payments');
SELECT system.create_lucid_entity_table('auth_user', 'coupons');
SELECT system.create_lucid_entity_table('auth_user', 'api_keys');
SELECT system.create_lucid_entity_table('world', 'worlds');
SELECT system.create_lucid_entity_table('world', 'regions');
SELECT system.create_lucid_entity_table('world', 'countries');
SELECT system.create_lucid_entity_table('world', 'kingdoms');
SELECT system.create_lucid_entity_table('world', 'empires');
SELECT system.create_lucid_entity_table('world', 'cities');
SELECT system.create_lucid_entity_table('world', 'villages');
SELECT system.create_lucid_entity_table('world', 'buildings');
SELECT system.create_lucid_entity_table('world', 'districts');
SELECT system.create_lucid_entity_table('world', 'road_networks');
SELECT system.create_lucid_entity_table('world', 'transportation_routes');
SELECT system.create_lucid_entity_table('world', 'ports');
SELECT system.create_lucid_entity_table('world', 'airports');
SELECT system.create_lucid_entity_table('world', 'space_ports');
SELECT system.create_lucid_entity_table('world', 'forests');
SELECT system.create_lucid_entity_table('world', 'mountains');
SELECT system.create_lucid_entity_table('world', 'lakes');
SELECT system.create_lucid_entity_table('world', 'oceans');
SELECT system.create_lucid_entity_table('world', 'dungeons');
SELECT system.create_lucid_entity_table('world', 'caves');
SELECT system.create_lucid_entity_table('world', 'ruins');
SELECT system.create_lucid_entity_table('world', 'castles');
SELECT system.create_lucid_entity_table('world', 'resources');
SELECT system.create_lucid_entity_table('world', 'animals');
SELECT system.create_lucid_entity_table('world', 'monsters');
SELECT system.create_lucid_entity_table('world', 'bosses');
SELECT system.create_lucid_entity_table('world', 'weather');
SELECT system.create_lucid_entity_table('world', 'climate');
SELECT system.create_lucid_entity_table('world', 'seasons');
SELECT system.create_lucid_entity_table('world', 'calendar');
SELECT system.create_lucid_entity_table('world', 'time_system');
SELECT system.create_lucid_entity_table('world', 'historical_timeline');
SELECT system.create_lucid_entity_table('world', 'historical_events');
SELECT system.create_lucid_entity_table('world', 'natural_disasters');
SELECT system.create_lucid_entity_table('world', 'festivals');
SELECT system.create_lucid_entity_table('world', 'wars');
SELECT system.create_lucid_entity_table('world', 'politics');
SELECT system.create_lucid_entity_table('world', 'government');
SELECT system.create_lucid_entity_table('world', 'laws');
SELECT system.create_lucid_entity_table('world', 'economy');
SELECT system.create_lucid_entity_table('world', 'currencies');
SELECT system.create_lucid_entity_table('world', 'banks');
SELECT system.create_lucid_entity_table('world', 'businesses');
SELECT system.create_lucid_entity_table('world', 'markets');
SELECT system.create_lucid_entity_table('world', 'shops');
SELECT system.create_lucid_entity_table('world', 'npc_population');
SELECT system.create_lucid_entity_table('world', 'population_statistics');
SELECT system.create_lucid_entity_table('world', 'dynamic_world_rules');
SELECT system.create_lucid_entity_table('world', 'world_events');
SELECT system.create_lucid_entity_table('world', 'world_event_history');
SELECT system.create_lucid_entity_table('story', 'stories');
SELECT system.create_lucid_entity_table('story', 'story_packs');
SELECT system.create_lucid_entity_table('story', 'story_genres');
SELECT system.create_lucid_entity_table('story', 'story_tags');
SELECT system.create_lucid_entity_table('story', 'story_categories');
SELECT system.create_lucid_entity_table('story', 'story_ratings');
SELECT system.create_lucid_entity_table('story', 'story_reviews');
SELECT system.create_lucid_entity_table('story', 'story_versions');
SELECT system.create_lucid_entity_table('story', 'story_drafts');
SELECT system.create_lucid_entity_table('story', 'story_publishing');
SELECT system.create_lucid_entity_table('story', 'story_chapters');
SELECT system.create_lucid_entity_table('story', 'story_scenes');
SELECT system.create_lucid_entity_table('story', 'story_nodes');
SELECT system.create_lucid_entity_table('story', 'choices');
SELECT system.create_lucid_entity_table('story', 'choice_requirements');
SELECT system.create_lucid_entity_table('story', 'choice_consequences');
SELECT system.create_lucid_entity_table('story', 'dialogue_trees');
SELECT system.create_lucid_entity_table('story', 'dialogue_options');
SELECT system.create_lucid_entity_table('story', 'plot_twists');
SELECT system.create_lucid_entity_table('story', 'story_branches');
SELECT system.create_lucid_entity_table('story', 'story_variables');
SELECT system.create_lucid_entity_table('story', 'story_conditions');
SELECT system.create_lucid_entity_table('story', 'story_checkpoints');
SELECT system.create_lucid_entity_table('story', 'story_timeline');
SELECT system.create_lucid_entity_table('story', 'story_history');
SELECT system.create_lucid_entity_table('story', 'multiple_endings');
SELECT system.create_lucid_entity_table('story', 'achievements');
SELECT system.create_lucid_entity_table('story', 'story_statistics');
SELECT system.create_lucid_entity_table('story', 'bookmarks');
SELECT system.create_lucid_entity_table('story', 'favorites');
SELECT system.create_lucid_entity_table('npc', 'npc_profiles');
SELECT system.create_lucid_entity_table('npc', 'npc_types');
SELECT system.create_lucid_entity_table('npc', 'npc_classes');
SELECT system.create_lucid_entity_table('npc', 'npc_occupations');
SELECT system.create_lucid_entity_table('npc', 'npc_personality');
SELECT system.create_lucid_entity_table('npc', 'npc_iq');
SELECT system.create_lucid_entity_table('npc', 'npc_skills');
SELECT system.create_lucid_entity_table('npc', 'npc_abilities');
SELECT system.create_lucid_entity_table('npc', 'npc_traits');
SELECT system.create_lucid_entity_table('npc', 'npc_goals');
SELECT system.create_lucid_entity_table('npc', 'npc_schedules');
SELECT system.create_lucid_entity_table('npc', 'npc_daily_routine');
SELECT system.create_lucid_entity_table('npc', 'npc_current_activity');
SELECT system.create_lucid_entity_table('npc', 'npc_locations');
SELECT system.create_lucid_entity_table('npc', 'npc_relationships');
SELECT system.create_lucid_entity_table('npc', 'npc_relationship_history');
SELECT system.create_lucid_entity_table('npc', 'npc_families');
SELECT system.create_lucid_entity_table('npc', 'npc_marriages');
SELECT system.create_lucid_entity_table('npc', 'npc_children');
SELECT system.create_lucid_entity_table('npc', 'npc_friends');
SELECT system.create_lucid_entity_table('npc', 'npc_enemies');
SELECT system.create_lucid_entity_table('npc', 'npc_guilds');
SELECT system.create_lucid_entity_table('npc', 'npc_factions');
SELECT system.create_lucid_entity_table('npc', 'npc_dialogue');
SELECT system.create_lucid_entity_table('npc', 'npc_conversation_history');
SELECT system.create_lucid_entity_table('npc', 'npc_memories');
SELECT system.create_lucid_entity_table('npc', 'npc_long_term_memory');
SELECT system.create_lucid_entity_table('npc', 'npc_short_term_memory');
SELECT system.create_lucid_entity_table('npc', 'npc_embeddings');
SELECT system.create_lucid_entity_table('npc', 'npc_emotions');
SELECT system.create_lucid_entity_table('npc', 'npc_mood');
SELECT system.create_lucid_entity_table('npc', 'npc_stress');
SELECT system.create_lucid_entity_table('npc', 'npc_fear');
SELECT system.create_lucid_entity_table('npc', 'npc_loyalty');
SELECT system.create_lucid_entity_table('npc', 'npc_respect');
SELECT system.create_lucid_entity_table('npc', 'npc_trust');
SELECT system.create_lucid_entity_table('npc', 'npc_affinity');
SELECT system.create_lucid_entity_table('npc', 'npc_gifts');
SELECT system.create_lucid_entity_table('npc', 'npc_promises');
SELECT system.create_lucid_entity_table('npc', 'npc_betrayals');
SELECT system.create_lucid_entity_table('npc', 'npc_inventory');
SELECT system.create_lucid_entity_table('npc', 'npc_equipment');
SELECT system.create_lucid_entity_table('npc', 'npc_statistics');
SELECT system.create_lucid_entity_table('npc', 'npc_reputation');
SELECT system.create_lucid_entity_table('npc', 'npc_titles');
SELECT system.create_lucid_entity_table('inventory', 'items');
SELECT system.create_lucid_entity_table('inventory', 'item_types');
SELECT system.create_lucid_entity_table('inventory', 'item_categories');
SELECT system.create_lucid_entity_table('inventory', 'item_rarities');
SELECT system.create_lucid_entity_table('inventory', 'weapons');
SELECT system.create_lucid_entity_table('inventory', 'weapon_types');
SELECT system.create_lucid_entity_table('inventory', 'armor');
SELECT system.create_lucid_entity_table('inventory', 'armor_types');
SELECT system.create_lucid_entity_table('inventory', 'accessories');
SELECT system.create_lucid_entity_table('inventory', 'consumables');
SELECT system.create_lucid_entity_table('inventory', 'magic_items');
SELECT system.create_lucid_entity_table('inventory', 'artifacts');
SELECT system.create_lucid_entity_table('inventory', 'relics');
SELECT system.create_lucid_entity_table('inventory', 'books');
SELECT system.create_lucid_entity_table('inventory', 'lore_scrolls');
SELECT system.create_lucid_entity_table('inventory', 'quest_items');
SELECT system.create_lucid_entity_table('inventory', 'crafting_materials');
SELECT system.create_lucid_entity_table('inventory', 'resources');
SELECT system.create_lucid_entity_table('inventory', 'recipes');
SELECT system.create_lucid_entity_table('inventory', 'crafting_stations');
SELECT system.create_lucid_entity_table('inventory', 'enchantments');
SELECT system.create_lucid_entity_table('inventory', 'item_attributes');
SELECT system.create_lucid_entity_table('inventory', 'item_statistics');
SELECT system.create_lucid_entity_table('inventory', 'item_durability');
SELECT system.create_lucid_entity_table('inventory', 'equipment_slots');
SELECT system.create_lucid_entity_table('inventory', 'player_inventory');
SELECT system.create_lucid_entity_table('inventory', 'npc_inventory');
SELECT system.create_lucid_entity_table('inventory', 'storage');
SELECT system.create_lucid_entity_table('inventory', 'warehouse');
SELECT system.create_lucid_entity_table('inventory', 'bank_storage');
SELECT system.create_lucid_entity_table('inventory', 'inventory_transactions');
SELECT system.create_lucid_entity_table('inventory', 'inventory_history');
SELECT system.create_lucid_entity_table('inventory', 'dropped_items');
SELECT system.create_lucid_entity_table('inventory', 'loot_tables');
SELECT system.create_lucid_entity_table('inventory', 'loot_drops');
SELECT system.create_lucid_entity_table('inventory', 'chest_loot');
SELECT system.create_lucid_entity_table('inventory', 'treasure_rewards');
SELECT system.create_lucid_entity_table('inventory', 'trading_items');
SELECT system.create_lucid_entity_table('combat', 'combat_classes');
SELECT system.create_lucid_entity_table('combat', 'player_classes');
SELECT system.create_lucid_entity_table('combat', 'npc_classes');
SELECT system.create_lucid_entity_table('combat', 'combat_skills');
SELECT system.create_lucid_entity_table('combat', 'abilities');
SELECT system.create_lucid_entity_table('combat', 'skill_trees');
SELECT system.create_lucid_entity_table('combat', 'skill_progression');
SELECT system.create_lucid_entity_table('combat', 'skill_cooldowns');
SELECT system.create_lucid_entity_table('combat', 'combat_effects');
SELECT system.create_lucid_entity_table('combat', 'buffs');
SELECT system.create_lucid_entity_table('combat', 'debuffs');
SELECT system.create_lucid_entity_table('combat', 'status_effects');
SELECT system.create_lucid_entity_table('combat', 'damage_types');
SELECT system.create_lucid_entity_table('combat', 'attack_types');
SELECT system.create_lucid_entity_table('combat', 'defense_types');
SELECT system.create_lucid_entity_table('combat', 'critical_hits');
SELECT system.create_lucid_entity_table('combat', 'healing');
SELECT system.create_lucid_entity_table('combat', 'mana');
SELECT system.create_lucid_entity_table('combat', 'energy');
SELECT system.create_lucid_entity_table('combat', 'stamina');
SELECT system.create_lucid_entity_table('combat', 'experience');
SELECT system.create_lucid_entity_table('combat', 'level_progression');
SELECT system.create_lucid_entity_table('combat', 'combat_statistics');
SELECT system.create_lucid_entity_table('combat', 'battle_history');
SELECT system.create_lucid_entity_table('combat', 'combat_logs');
SELECT system.create_lucid_entity_table('combat', 'boss_battles');
SELECT system.create_lucid_entity_table('combat', 'arena_battles');
SELECT system.create_lucid_entity_table('combat', 'pvp');
SELECT system.create_lucid_entity_table('combat', 'pve');
SELECT system.create_lucid_entity_table('progression', 'quest_categories');
SELECT system.create_lucid_entity_table('progression', 'quest_types');
SELECT system.create_lucid_entity_table('progression', 'main_quests');
SELECT system.create_lucid_entity_table('progression', 'side_quests');
SELECT system.create_lucid_entity_table('progression', 'daily_quests');
SELECT system.create_lucid_entity_table('progression', 'weekly_quests');
SELECT system.create_lucid_entity_table('progression', 'procedural_quests');
SELECT system.create_lucid_entity_table('progression', 'quest_chains');
SELECT system.create_lucid_entity_table('progression', 'quest_objectives');
SELECT system.create_lucid_entity_table('progression', 'quest_conditions');
SELECT system.create_lucid_entity_table('progression', 'quest_rewards');
SELECT system.create_lucid_entity_table('progression', 'quest_penalties');
SELECT system.create_lucid_entity_table('progression', 'quest_branches');
SELECT system.create_lucid_entity_table('progression', 'quest_choices');
SELECT system.create_lucid_entity_table('progression', 'quest_variables');
SELECT system.create_lucid_entity_table('progression', 'quest_progress');
SELECT system.create_lucid_entity_table('progression', 'quest_completion');
SELECT system.create_lucid_entity_table('progression', 'quest_failure');
SELECT system.create_lucid_entity_table('progression', 'quest_history');
SELECT system.create_lucid_entity_table('progression', 'quest_statistics');
SELECT system.create_lucid_entity_table('progression', 'achievement_categories');
SELECT system.create_lucid_entity_table('multiplayer', 'game_sessions');
SELECT system.create_lucid_entity_table('multiplayer', 'multiplayer_sessions');
SELECT system.create_lucid_entity_table('multiplayer', 'session_players');
SELECT system.create_lucid_entity_table('multiplayer', 'party_system');
SELECT system.create_lucid_entity_table('multiplayer', 'party_members');
SELECT system.create_lucid_entity_table('multiplayer', 'party_roles');
SELECT system.create_lucid_entity_table('multiplayer', 'party_invitations');
SELECT system.create_lucid_entity_table('multiplayer', 'party_chat');
SELECT system.create_lucid_entity_table('multiplayer', 'party_permissions');
SELECT system.create_lucid_entity_table('multiplayer', 'friend_invitations');
SELECT system.create_lucid_entity_table('multiplayer', 'player_invitations');
SELECT system.create_lucid_entity_table('multiplayer', 'shared_worlds');
SELECT system.create_lucid_entity_table('multiplayer', 'shared_stories');
SELECT system.create_lucid_entity_table('multiplayer', 'shared_quests');
SELECT system.create_lucid_entity_table('multiplayer', 'shared_inventories');
SELECT system.create_lucid_entity_table('multiplayer', 'voice_chat_metadata');
SELECT system.create_lucid_entity_table('multiplayer', 'voice_rooms');
SELECT system.create_lucid_entity_table('multiplayer', 'player_presence');
SELECT system.create_lucid_entity_table('multiplayer', 'online_status');
SELECT system.create_lucid_entity_table('multiplayer', 'matchmaking');
SELECT system.create_lucid_entity_table('multiplayer', 'lobby_system');
SELECT system.create_lucid_entity_table('multiplayer', 'lobby_members');
SELECT system.create_lucid_entity_table('multiplayer', 'host_migration');
SELECT system.create_lucid_entity_table('multiplayer', 'player_synchronization');
SELECT system.create_lucid_entity_table('multiplayer', 'session_logs');
SELECT system.create_lucid_entity_table('guild', 'guilds');
SELECT system.create_lucid_entity_table('guild', 'guild_members');
SELECT system.create_lucid_entity_table('guild', 'guild_roles');
SELECT system.create_lucid_entity_table('guild', 'guild_permissions');
SELECT system.create_lucid_entity_table('guild', 'guild_invitations');
SELECT system.create_lucid_entity_table('guild', 'guild_chat');
SELECT system.create_lucid_entity_table('guild', 'guild_events');
SELECT system.create_lucid_entity_table('guild', 'guild_history');
SELECT system.create_lucid_entity_table('guild', 'guild_storage');
SELECT system.create_lucid_entity_table('guild', 'guild_achievements');
SELECT system.create_lucid_entity_table('guild', 'guild_rankings');
SELECT system.create_lucid_entity_table('creator', 'creators');
SELECT system.create_lucid_entity_table('creator', 'creator_profiles');
SELECT system.create_lucid_entity_table('creator', 'creator_teams');
SELECT system.create_lucid_entity_table('creator', 'team_members');
SELECT system.create_lucid_entity_table('creator', 'collaborators');
SELECT system.create_lucid_entity_table('creator', 'world_builder');
SELECT system.create_lucid_entity_table('creator', 'story_builder');
SELECT system.create_lucid_entity_table('creator', 'quest_builder');
SELECT system.create_lucid_entity_table('creator', 'npc_builder');
SELECT system.create_lucid_entity_table('creator', 'item_builder');
SELECT system.create_lucid_entity_table('creator', 'building_builder');
SELECT system.create_lucid_entity_table('creator', 'map_builder');
SELECT system.create_lucid_entity_table('creator', 'dialogue_builder');
SELECT system.create_lucid_entity_table('creator', 'voice_pack_builder');
SELECT system.create_lucid_entity_table('creator', 'image_pack_builder');
SELECT system.create_lucid_entity_table('creator', 'music_pack_builder');
SELECT system.create_lucid_entity_table('creator', 'animation_pack_builder');
SELECT system.create_lucid_entity_table('creator', 'story_pack_builder');
SELECT system.create_lucid_entity_table('creator', 'creator_drafts');
SELECT system.create_lucid_entity_table('creator', 'draft_versions');
SELECT system.create_lucid_entity_table('creator', 'publishing_queue');
SELECT system.create_lucid_entity_table('creator', 'publishing_workflow');
SELECT system.create_lucid_entity_table('creator', 'publishing_history');
SELECT system.create_lucid_entity_table('creator', 'approval_queue');
SELECT system.create_lucid_entity_table('creator', 'moderation_queue');
SELECT system.create_lucid_entity_table('creator', 'creator_analytics');
SELECT system.create_lucid_entity_table('creator', 'creator_revenue');
SELECT system.create_lucid_entity_table('creator', 'creator_followers');
SELECT system.create_lucid_entity_table('creator', 'creator_ratings');
SELECT system.create_lucid_entity_table('creator', 'creator_reviews');
SELECT system.create_lucid_entity_table('creator', 'creator_achievements');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_categories');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_assets');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_listings');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_orders');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_reviews');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_ratings');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_wishlists');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_favorites');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_cart');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_coupons');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_discounts');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_taxes');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_refunds');
SELECT system.create_lucid_entity_table('marketplace', 'marketplace_revenue');
SELECT system.create_lucid_entity_table('marketplace', 'creator_earnings');
SELECT system.create_lucid_entity_table('marketplace', 'creator_payouts');
SELECT system.create_lucid_entity_table('marketplace', 'payment_methods');
SELECT system.create_lucid_entity_table('marketplace', 'payment_history');
SELECT system.create_lucid_entity_table('marketplace', 'invoices');
SELECT system.create_lucid_entity_table('marketplace', 'purchase_history');
SELECT system.create_lucid_entity_table('marketplace', 'sales_history');
SELECT system.create_lucid_entity_table('marketplace', 'asset_ownership');
SELECT system.create_lucid_entity_table('marketplace', 'asset_licensing');
SELECT system.create_lucid_entity_table('marketplace', 'asset_versions');
SELECT system.create_lucid_entity_table('marketplace', 'asset_tags');
SELECT system.create_lucid_entity_table('marketplace', 'asset_categories');
SELECT system.create_lucid_entity_table('marketplace', 'story_packs');
SELECT system.create_lucid_entity_table('marketplace', 'voice_packs');
SELECT system.create_lucid_entity_table('marketplace', 'npc_packs');
SELECT system.create_lucid_entity_table('marketplace', 'character_skins');
SELECT system.create_lucid_entity_table('marketplace', 'visual_themes');
SELECT system.create_lucid_entity_table('marketplace', 'world_packs');
SELECT system.create_lucid_entity_table('marketplace', 'quest_packs');
SELECT system.create_lucid_entity_table('marketplace', 'animation_packs');
SELECT system.create_lucid_entity_table('marketplace', 'music_packs');
SELECT system.create_lucid_entity_table('marketplace', 'image_packs');
SELECT system.create_lucid_entity_table('marketplace', 'premium_assets');
SELECT system.create_lucid_entity_table('marketplace', 'free_assets');
SELECT system.create_lucid_entity_table('marketplace', 'featured_assets');
SELECT system.create_lucid_entity_table('marketplace', 'trending_assets');
SELECT system.create_lucid_entity_table('marketplace', 'recently_added_assets');
SELECT system.create_lucid_entity_table('ai', 'ai_providers');
SELECT system.create_lucid_entity_table('ai', 'ai_models');
SELECT system.create_lucid_entity_table('ai', 'ai_model_versions');
SELECT system.create_lucid_entity_table('ai', 'ai_configuration');
SELECT system.create_lucid_entity_table('ai', 'ai_prompts');
SELECT system.create_lucid_entity_table('ai', 'prompt_templates');
SELECT system.create_lucid_entity_table('ai', 'prompt_variables');
SELECT system.create_lucid_entity_table('ai', 'prompt_categories');
SELECT system.create_lucid_entity_table('ai', 'prompt_history');
SELECT system.create_lucid_entity_table('ai', 'ai_requests');
SELECT system.create_lucid_entity_table('ai', 'ai_responses');
SELECT system.create_lucid_entity_table('ai', 'ai_conversations');
SELECT system.create_lucid_entity_table('ai', 'ai_conversation_history');
SELECT system.create_lucid_entity_table('ai', 'story_generation_requests');
SELECT system.create_lucid_entity_table('ai', 'story_generation_history');
SELECT system.create_lucid_entity_table('ai', 'npc_dialogue_requests');
SELECT system.create_lucid_entity_table('ai', 'npc_dialogue_history');
SELECT system.create_lucid_entity_table('ai', 'memory_generation');
SELECT system.create_lucid_entity_table('ai', 'memory_consolidation');
SELECT system.create_lucid_entity_table('ai', 'relationship_updates');
SELECT system.create_lucid_entity_table('ai', 'emotion_analysis');
SELECT system.create_lucid_entity_table('ai', 'quest_generation');
SELECT system.create_lucid_entity_table('ai', 'recommendation_engine');
SELECT system.create_lucid_entity_table('ai', 'world_simulation');
SELECT system.create_lucid_entity_table('ai', 'ai_generated_images');
SELECT system.create_lucid_entity_table('ai', 'ai_generated_voices');
SELECT system.create_lucid_entity_table('ai', 'ai_generated_music');
SELECT system.create_lucid_entity_table('ai', 'ai_generated_videos');
SELECT system.create_lucid_entity_table('ai', 'ai_generated_assets');
SELECT system.create_lucid_entity_table('ai', 'ai_usage_statistics');
SELECT system.create_lucid_entity_table('ai', 'ai_token_usage');
SELECT system.create_lucid_entity_table('ai', 'ai_costs');
SELECT system.create_lucid_entity_table('ai', 'ai_billing');
SELECT system.create_lucid_entity_table('ai', 'ai_rate_limits');
SELECT system.create_lucid_entity_table('ai', 'ai_cache_metadata');
SELECT system.create_lucid_entity_table('ai', 'ai_embeddings');
SELECT system.create_lucid_entity_table('ai', 'vector_metadata');
SELECT system.create_lucid_entity_table('ai', 'vector_collections');
SELECT system.create_lucid_entity_table('ai', 'embedding_history');
SELECT system.create_lucid_entity_table('ai', 'inference_logs');
SELECT system.create_lucid_entity_table('ai', 'safety_checks');
SELECT system.create_lucid_entity_table('ai', 'content_moderation_logs');
SELECT system.create_lucid_entity_table('ai', 'prompt_safety_logs');
SELECT system.create_lucid_entity_table('ai', 'ai_error_logs');
SELECT system.create_lucid_entity_table('ai', 'ai_performance_metrics');
SELECT system.create_lucid_entity_table('media', 'images');
SELECT system.create_lucid_entity_table('media', 'image_metadata');
SELECT system.create_lucid_entity_table('media', 'image_versions');
SELECT system.create_lucid_entity_table('media', 'image_tags');
SELECT system.create_lucid_entity_table('media', 'voice_assets');
SELECT system.create_lucid_entity_table('media', 'voice_metadata');
SELECT system.create_lucid_entity_table('media', 'voice_profiles');
SELECT system.create_lucid_entity_table('media', 'audio_files');
SELECT system.create_lucid_entity_table('media', 'music_library');
SELECT system.create_lucid_entity_table('media', 'music_metadata');
SELECT system.create_lucid_entity_table('media', 'sound_effects');
SELECT system.create_lucid_entity_table('media', 'video_assets');
SELECT system.create_lucid_entity_table('media', 'video_metadata');
SELECT system.create_lucid_entity_table('media', 'animation_assets');
SELECT system.create_lucid_entity_table('media', 'animation_metadata');
SELECT system.create_lucid_entity_table('media', 'asset_storage');
SELECT system.create_lucid_entity_table('media', 'asset_cdn_references');
SELECT system.create_lucid_entity_table('media', 'asset_compression');
SELECT system.create_lucid_entity_table('media', 'asset_optimization');
SELECT system.create_lucid_entity_table('media', 'asset_processing_queue');
SELECT system.create_lucid_entity_table('journal', 'player_journals');
SELECT system.create_lucid_entity_table('journal', 'journal_categories');
SELECT system.create_lucid_entity_table('journal', 'journal_entries');
SELECT system.create_lucid_entity_table('journal', 'journal_tags');
SELECT system.create_lucid_entity_table('journal', 'journal_attachments');
SELECT system.create_lucid_entity_table('journal', 'journal_history');
SELECT system.create_lucid_entity_table('journal', 'bookmarks');
SELECT system.create_lucid_entity_table('journal', 'notes');
SELECT system.create_lucid_entity_table('journal', 'diary_entries');
SELECT system.create_lucid_entity_table('journal', 'story_logs');
SELECT system.create_lucid_entity_table('journal', 'player_decisions');
SELECT system.create_lucid_entity_table('journal', 'choice_history');
SELECT system.create_lucid_entity_table('journal', 'session_history');
SELECT system.create_lucid_entity_table('recommendation', 'story_recommendations');
SELECT system.create_lucid_entity_table('recommendation', 'quest_recommendations');
SELECT system.create_lucid_entity_table('recommendation', 'npc_recommendations');
SELECT system.create_lucid_entity_table('recommendation', 'world_recommendations');
SELECT system.create_lucid_entity_table('recommendation', 'asset_recommendations');
SELECT system.create_lucid_entity_table('recommendation', 'recommendation_scores');
SELECT system.create_lucid_entity_table('recommendation', 'recommendation_history');
SELECT system.create_lucid_entity_table('recommendation', 'recommendation_feedback');
SELECT system.create_lucid_entity_table('recommendation', 'recommendation_preferences');
SELECT system.create_lucid_entity_table('recommendation', 'recommendation_analytics');
SELECT system.create_lucid_entity_table('analytics', 'player_analytics');
SELECT system.create_lucid_entity_table('analytics', 'gameplay_analytics');
SELECT system.create_lucid_entity_table('analytics', 'session_analytics');
SELECT system.create_lucid_entity_table('analytics', 'story_analytics');
SELECT system.create_lucid_entity_table('analytics', 'quest_analytics');
SELECT system.create_lucid_entity_table('analytics', 'combat_analytics');
SELECT system.create_lucid_entity_table('analytics', 'economy_analytics');
SELECT system.create_lucid_entity_table('analytics', 'marketplace_analytics');
SELECT system.create_lucid_entity_table('analytics', 'creator_analytics');
SELECT system.create_lucid_entity_table('analytics', 'ai_analytics');
SELECT system.create_lucid_entity_table('analytics', 'revenue_analytics');
SELECT system.create_lucid_entity_table('analytics', 'engagement_analytics');
SELECT system.create_lucid_entity_table('analytics', 'retention_analytics');
SELECT system.create_lucid_entity_table('analytics', 'crash_reports');
SELECT system.create_lucid_entity_table('analytics', 'performance_metrics');
SELECT system.create_lucid_entity_table('analytics', 'database_metrics');
SELECT system.create_lucid_entity_table('analytics', 'api_metrics');
SELECT system.create_lucid_entity_table('analytics', 'usage_statistics');
SELECT system.create_lucid_entity_table('analytics', 'dashboards');
SELECT system.create_lucid_entity_table('analytics', 'reports');
SELECT system.create_lucid_entity_table('moderation', 'reports');
SELECT system.create_lucid_entity_table('moderation', 'report_categories');
SELECT system.create_lucid_entity_table('moderation', 'report_evidence');
SELECT system.create_lucid_entity_table('moderation', 'report_status');
SELECT system.create_lucid_entity_table('moderation', 'moderators');
SELECT system.create_lucid_entity_table('moderation', 'moderator_actions');
SELECT system.create_lucid_entity_table('moderation', 'warnings');
SELECT system.create_lucid_entity_table('moderation', 'suspensions');
SELECT system.create_lucid_entity_table('moderation', 'temporary_bans');
SELECT system.create_lucid_entity_table('moderation', 'permanent_bans');
SELECT system.create_lucid_entity_table('moderation', 'appeals');
SELECT system.create_lucid_entity_table('moderation', 'appeal_decisions');
SELECT system.create_lucid_entity_table('moderation', 'content_flags');
SELECT system.create_lucid_entity_table('moderation', 'blocked_content');
SELECT system.create_lucid_entity_table('moderation', 'moderation_queue');
SELECT system.create_lucid_entity_table('moderation', 'moderation_history');
SELECT system.create_lucid_entity_table('notification', 'notification_templates');
SELECT system.create_lucid_entity_table('notification', 'notification_categories');
SELECT system.create_lucid_entity_table('notification', 'notification_preferences');
SELECT system.create_lucid_entity_table('notification', 'email_notifications');
SELECT system.create_lucid_entity_table('notification', 'push_notifications');
SELECT system.create_lucid_entity_table('notification', 'sms_notifications');
SELECT system.create_lucid_entity_table('notification', 'system_announcements');
SELECT system.create_lucid_entity_table('notification', 'inbox_messages');
SELECT system.create_lucid_entity_table('notification', 'scheduled_notifications');
SELECT system.create_lucid_entity_table('notification', 'notification_history');
SELECT system.create_lucid_entity_table('notification', 'notification_types');
SELECT system.create_lucid_entity_table('social', 'friends');
SELECT system.create_lucid_entity_table('social', 'friend_requests');
SELECT system.create_lucid_entity_table('social', 'followers');
SELECT system.create_lucid_entity_table('social', 'following');
SELECT system.create_lucid_entity_table('social', 'player_profiles');
SELECT system.create_lucid_entity_table('social', 'player_status');
SELECT system.create_lucid_entity_table('social', 'player_activity');
SELECT system.create_lucid_entity_table('social', 'player_feed');
SELECT system.create_lucid_entity_table('social', 'comments');
SELECT system.create_lucid_entity_table('social', 'likes');
SELECT system.create_lucid_entity_table('social', 'reactions');
SELECT system.create_lucid_entity_table('social', 'shares');
SELECT system.create_lucid_entity_table('social', 'mentions');
SELECT system.create_lucid_entity_table('social', 'tags');
SELECT system.create_lucid_entity_table('social', 'private_messages');
SELECT system.create_lucid_entity_table('social', 'group_messages');
SELECT system.create_lucid_entity_table('social', 'chat_channels');
SELECT system.create_lucid_entity_table('social', 'chat_history');
SELECT system.create_lucid_entity_table('social', 'voice_chat_metadata');
SELECT system.create_lucid_entity_table('subscription', 'subscription_plans');
SELECT system.create_lucid_entity_table('subscription', 'premium_features');
SELECT system.create_lucid_entity_table('subscription', 'premium_users');
SELECT system.create_lucid_entity_table('subscription', 'memberships');
SELECT system.create_lucid_entity_table('subscription', 'billing');
SELECT system.create_lucid_entity_table('subscription', 'invoices');
SELECT system.create_lucid_entity_table('subscription', 'payments');
SELECT system.create_lucid_entity_table('subscription', 'payment_history');
SELECT system.create_lucid_entity_table('subscription', 'payment_providers');
SELECT system.create_lucid_entity_table('subscription', 'refunds');
SELECT system.create_lucid_entity_table('subscription', 'discounts');
SELECT system.create_lucid_entity_table('subscription', 'coupons');
SELECT system.create_lucid_entity_table('subscription', 'taxes');
SELECT system.create_lucid_entity_table('subscription', 'revenue');
SELECT system.create_lucid_entity_table('admin', 'admin_users');
SELECT system.create_lucid_entity_table('admin', 'admin_roles');
SELECT system.create_lucid_entity_table('admin', 'admin_permissions');
SELECT system.create_lucid_entity_table('admin', 'admin_activity_logs');
SELECT system.create_lucid_entity_table('admin', 'system_configuration');
SELECT system.create_lucid_entity_table('admin', 'feature_flags');
SELECT system.create_lucid_entity_table('admin', 'maintenance_mode');
SELECT system.create_lucid_entity_table('admin', 'server_configuration');
SELECT system.create_lucid_entity_table('admin', 'api_configuration');
SELECT system.create_lucid_entity_table('admin', 'application_settings');
SELECT system.create_lucid_entity_table('system', 'application_configuration');
SELECT system.create_lucid_entity_table('system', 'system_settings');
SELECT system.create_lucid_entity_table('system', 'background_jobs');
SELECT system.create_lucid_entity_table('system', 'job_queue');
SELECT system.create_lucid_entity_table('system', 'cron_jobs');
SELECT system.create_lucid_entity_table('system', 'scheduler');
SELECT system.create_lucid_entity_table('system', 'cache_metadata');
SELECT system.create_lucid_entity_table('system', 'redis_metadata');
SELECT system.create_lucid_entity_table('system', 'search_metadata');
SELECT system.create_lucid_entity_table('system', 'feature_toggles');
SELECT system.create_lucid_entity_table('system', 'health_checks');
SELECT system.create_lucid_entity_table('system', 'monitoring');
SELECT system.create_lucid_entity_table('system', 'error_logs');
SELECT system.create_lucid_entity_table('system', 'event_logs');
SELECT system.create_lucid_entity_table('system', 'backup_metadata');
SELECT system.create_lucid_entity_table('system', 'restore_metadata');
SELECT system.create_lucid_entity_table('system', 'migration_history');
SELECT system.create_lucid_entity_table('system', 'version_history');
SELECT system.create_lucid_entity_table('system', 'slow_queries');
SELECT system.create_lucid_entity_table('system', 'index_usage');
SELECT system.create_lucid_entity_table('system', 'storage_usage');
SELECT system.create_lucid_entity_table('system', 'cache_statistics');
SELECT system.create_lucid_entity_table('economy', 'economy_rules');
SELECT system.create_lucid_entity_table('economy', 'currency_rates');
SELECT system.create_lucid_entity_table('economy', 'market_prices');
SELECT system.create_lucid_entity_table('economy', 'bank_accounts');
SELECT system.create_lucid_entity_table('economy', 'economic_events');
SELECT system.create_lucid_entity_table('politics', 'governments');
SELECT system.create_lucid_entity_table('politics', 'laws');
SELECT system.create_lucid_entity_table('politics', 'elections');
SELECT system.create_lucid_entity_table('politics', 'factions');
SELECT system.create_lucid_entity_table('politics', 'political_events');
SELECT system.create_lucid_entity_table('weather', 'weather_types');
SELECT system.create_lucid_entity_table('weather', 'weather_forecasts');
SELECT system.create_lucid_entity_table('weather', 'climate_zones');
SELECT system.create_lucid_entity_table('weather', 'seasonal_patterns');
SELECT system.create_lucid_entity_table('transportation', 'routes');
SELECT system.create_lucid_entity_table('transportation', 'vehicles');
SELECT system.create_lucid_entity_table('transportation', 'stations');
SELECT system.create_lucid_entity_table('transportation', 'ports');
SELECT system.create_lucid_entity_table('transportation', 'schedules');
SELECT system.create_lucid_entity_table('business', 'businesses');
SELECT system.create_lucid_entity_table('business', 'business_types');
SELECT system.create_lucid_entity_table('business', 'employees');
SELECT system.create_lucid_entity_table('business', 'transactions');
SELECT system.create_lucid_entity_table('business', 'ledgers');

CREATE TABLE analytics.player_events (
  id UUID DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL, event_data JSONB NOT NULL DEFAULT '{}', user_id UUID REFERENCES auth_user.users(id), world_id UUID, story_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ,
  PRIMARY KEY(id, occurred_at)
) PARTITION BY RANGE (occurred_at);
CREATE INDEX idx_analytics_player_events_created ON analytics.player_events(created_at DESC);
CREATE INDEX idx_analytics_player_events_event_data_gin ON analytics.player_events USING gin(event_data);
CREATE TRIGGER trg_analytics_player_events_touch BEFORE UPDATE ON analytics.player_events FOR EACH ROW EXECUTE FUNCTION system.touch_updated_at();

CREATE TABLE notification.notifications (
  id UUID DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth_user.users(id), channel system.notification_channel NOT NULL DEFAULT 'in_app', title TEXT NOT NULL, body TEXT NOT NULL, payload JSONB NOT NULL DEFAULT '{}', read_at TIMESTAMPTZ, delivered_at TIMESTAMPTZ, scheduled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ,
  PRIMARY KEY(id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX idx_notification_notifications_created ON notification.notifications(created_at DESC);
CREATE INDEX idx_notification_notifications_payload_gin ON notification.notifications USING gin(payload);
CREATE TRIGGER trg_notification_notifications_touch BEFORE UPDATE ON notification.notifications FOR EACH ROW EXECUTE FUNCTION system.touch_updated_at();

CREATE TABLE ai.ai_request_logs (
  id UUID DEFAULT gen_random_uuid(),
  owner_user_id UUID REFERENCES auth_user.users(id), provider TEXT, model TEXT, status system.ai_request_status NOT NULL DEFAULT 'queued', prompt_tokens BIGINT DEFAULT 0, completion_tokens BIGINT DEFAULT 0, cost NUMERIC(20,6) DEFAULT 0, request_payload JSONB NOT NULL DEFAULT '{}', response_payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ,
  PRIMARY KEY(id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX idx_ai_ai_request_logs_created ON ai.ai_request_logs(created_at DESC);
CREATE INDEX idx_ai_ai_request_logs_payload_gin ON ai.ai_request_logs USING gin(payload);
CREATE INDEX idx_ai_ai_request_logs_request_payload_gin ON ai.ai_request_logs USING gin(request_payload);
CREATE INDEX idx_ai_ai_request_logs_response_payload_gin ON ai.ai_request_logs USING gin(response_payload);
CREATE TRIGGER trg_ai_ai_request_logs_touch BEFORE UPDATE ON ai.ai_request_logs FOR EACH ROW EXECUTE FUNCTION system.touch_updated_at();

CREATE TABLE ai.conversation_history_events (
  id UUID DEFAULT gen_random_uuid(),
  owner_user_id UUID REFERENCES auth_user.users(id), conversation_id UUID, npc_id UUID, story_id UUID, role TEXT NOT NULL, content TEXT NOT NULL, embedding vector(1536), metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ,
  PRIMARY KEY(id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX idx_ai_conversation_history_events_created ON ai.conversation_history_events(created_at DESC);
CREATE INDEX idx_ai_conversation_history_events_metadata_gin ON ai.conversation_history_events USING gin(metadata);
CREATE INDEX idx_ai_conversation_history_events_embedding_hnsw ON ai.conversation_history_events USING hnsw (embedding vector_cosine_ops);
CREATE TRIGGER trg_ai_conversation_history_events_touch BEFORE UPDATE ON ai.conversation_history_events FOR EACH ROW EXECUTE FUNCTION system.touch_updated_at();

CREATE TABLE marketplace.marketplace_transactions (
  id UUID DEFAULT gen_random_uuid(),
  buyer_user_id UUID REFERENCES auth_user.users(id), seller_user_id UUID REFERENCES auth_user.users(id), asset_id UUID, order_id UUID, status system.transaction_status NOT NULL DEFAULT 'pending', gross_amount NUMERIC(20,6) NOT NULL DEFAULT 0, platform_fee NUMERIC(20,6) NOT NULL DEFAULT 0, net_amount NUMERIC(20,6) NOT NULL DEFAULT 0, metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ,
  PRIMARY KEY(id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX idx_marketplace_marketplace_transactions_created ON marketplace.marketplace_transactions(created_at DESC);
CREATE INDEX idx_marketplace_marketplace_transactions_metadata_gin ON marketplace.marketplace_transactions USING gin(metadata);
CREATE TRIGGER trg_marketplace_marketplace_transactions_touch BEFORE UPDATE ON marketplace.marketplace_transactions FOR EACH ROW EXECUTE FUNCTION system.touch_updated_at();

CREATE TABLE system.system_logs (
  id UUID DEFAULT gen_random_uuid(),
  level TEXT NOT NULL, source TEXT NOT NULL, message TEXT NOT NULL, details JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth_user.users(id), updated_by UUID REFERENCES auth_user.users(id),
  version BIGINT NOT NULL DEFAULT 1, deleted_at TIMESTAMPTZ,
  PRIMARY KEY(id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX idx_system_system_logs_created ON system.system_logs(created_at DESC);
CREATE INDEX idx_system_system_logs_details_gin ON system.system_logs USING gin(details);
CREATE TRIGGER trg_system_system_logs_touch BEFORE UPDATE ON system.system_logs FOR EACH ROW EXECUTE FUNCTION system.touch_updated_at();

CREATE OR REPLACE FUNCTION system.create_monthly_partitions(p_parent REGCLASS, p_date_column TEXT, p_months_ahead INT DEFAULT 24)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE i INT; start_date DATE; end_date DATE; child_name TEXT;
BEGIN
  FOR i IN -1..p_months_ahead LOOP
    start_date := (date_trunc('month', now()) + (i || ' months')::interval)::date;
    end_date := start_date + INTERVAL '1 month';
    child_name := replace(p_parent::text, '.', '_') || '_' || to_char(start_date, 'YYYY_MM');
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF %s FOR VALUES FROM (%L) TO (%L)', child_name, p_parent, start_date, end_date);
  END LOOP;
END;
$$;

SELECT system.create_monthly_partitions('audit.audit_logs'::regclass, 'occurred_at', 36);
SELECT system.create_monthly_partitions('history.entity_history'::regclass, 'changed_at', 36);
SELECT system.create_monthly_partitions('analytics.player_events'::regclass, 'occurred_at', 36);
SELECT system.create_monthly_partitions('notification.notifications'::regclass, 'created_at', 36);
SELECT system.create_monthly_partitions('ai.ai_request_logs'::regclass, 'created_at', 36);
SELECT system.create_monthly_partitions('ai.conversation_history_events'::regclass, 'created_at', 36);
SELECT system.create_monthly_partitions('marketplace.marketplace_transactions'::regclass, 'created_at', 36);
SELECT system.create_monthly_partitions('system.system_logs'::regclass, 'created_at', 36);

CREATE OR REPLACE FUNCTION progression.calculate_level(p_xp BIGINT) RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT GREATEST(1, floor(sqrt(GREATEST(p_xp,0) / 100.0))::INT + 1); $$;
CREATE OR REPLACE FUNCTION npc.relationship_score(p_trust NUMERIC, p_respect NUMERIC, p_affinity NUMERIC, p_fear NUMERIC) RETURNS NUMERIC LANGUAGE sql IMMUTABLE AS $$ SELECT LEAST(100, GREATEST(-100, (p_trust*.35)+(p_respect*.25)+(p_affinity*.30)-(p_fear*.10))); $$;
CREATE OR REPLACE FUNCTION combat.calculate_damage(p_attack NUMERIC, p_defense NUMERIC, p_multiplier NUMERIC DEFAULT 1) RETURNS NUMERIC LANGUAGE sql IMMUTABLE AS $$ SELECT GREATEST(0, (p_attack*p_multiplier)-(p_defense*.5)); $$;
CREATE OR REPLACE FUNCTION marketplace.platform_fee(p_amount NUMERIC, p_rate NUMERIC DEFAULT 0.15) RETURNS NUMERIC LANGUAGE sql IMMUTABLE AS $$ SELECT round(GREATEST(p_amount,0) * p_rate, 6); $$;
CREATE OR REPLACE FUNCTION recommendation.recommendation_score(p_similarity NUMERIC, p_quality NUMERIC, p_recency NUMERIC) RETURNS NUMERIC LANGUAGE sql IMMUTABLE AS $$ SELECT (p_similarity*.60)+(p_quality*.30)+(p_recency*.10); $$;
CREATE OR REPLACE FUNCTION ai.semantic_search(p_table REGCLASS, p_embedding vector(1536), p_limit INT DEFAULT 10) RETURNS TABLE(id UUID, name TEXT, distance FLOAT) LANGUAGE plpgsql AS $$ BEGIN RETURN QUERY EXECUTE format('SELECT id, name, embedding <=> $1 AS distance FROM %s WHERE embedding IS NOT NULL AND deleted_at IS NULL ORDER BY embedding <=> $1 LIMIT $2', p_table) USING p_embedding, p_limit; END; $$;

CREATE OR REPLACE PROCEDURE auth_user.register_user(p_email system.email, p_username TEXT, p_password_hash TEXT, p_display_name TEXT) LANGUAGE plpgsql AS $$ BEGIN INSERT INTO auth_user.users(email, username, password_hash, display_name) VALUES (p_email, p_username, p_password_hash, p_display_name); END; $$;
CREATE OR REPLACE PROCEDURE story.create_story(p_owner_user_id UUID, p_name TEXT, p_description TEXT) LANGUAGE plpgsql AS $$ BEGIN INSERT INTO story.stories(owner_user_id, name, description, status, visibility) VALUES (p_owner_user_id, p_name, p_description, 'draft', 'private'); END; $$;
CREATE OR REPLACE PROCEDURE story.publish_story(p_story_id UUID) LANGUAGE plpgsql AS $$ BEGIN UPDATE story.stories SET status='published', visibility='public', published_at=now() WHERE id=p_story_id AND deleted_at IS NULL; END; $$;
CREATE OR REPLACE PROCEDURE npc.update_npc_memory(p_npc_id UUID, p_owner_user_id UUID, p_memory TEXT, p_embedding vector(1536)) LANGUAGE plpgsql AS $$ BEGIN INSERT INTO npc.npc_memories(owner_user_id, npc_id, name, description, embedding, metadata) VALUES (p_owner_user_id, p_npc_id, left(p_memory, 120), p_memory, p_embedding, jsonb_build_object('memory_type','long_term')); END; $$;
CREATE OR REPLACE PROCEDURE marketplace.purchase_asset(p_buyer_user_id UUID, p_seller_user_id UUID, p_asset_id UUID, p_amount NUMERIC) LANGUAGE plpgsql AS $$ DECLARE v_fee NUMERIC; BEGIN v_fee := marketplace.platform_fee(p_amount); INSERT INTO marketplace.marketplace_transactions(buyer_user_id, seller_user_id, asset_id, status, gross_amount, platform_fee, net_amount) VALUES (p_buyer_user_id, p_seller_user_id, p_asset_id, 'paid', p_amount, v_fee, p_amount - v_fee); INSERT INTO marketplace.asset_ownership(owner_user_id, asset_id, name, metadata) VALUES (p_buyer_user_id, p_asset_id, 'owned_asset', jsonb_build_object('asset_id', p_asset_id)); END; $$;
CREATE OR REPLACE PROCEDURE multiplayer.join_multiplayer_session(p_session_id UUID, p_user_id UUID) LANGUAGE plpgsql AS $$ BEGIN INSERT INTO multiplayer.session_players(owner_user_id, parent_id, name, metadata) VALUES (p_user_id, p_session_id, 'session_player', jsonb_build_object('session_id', p_session_id)); END; $$;
CREATE OR REPLACE PROCEDURE multiplayer.leave_multiplayer_session(p_session_id UUID, p_user_id UUID) LANGUAGE plpgsql AS $$ BEGIN UPDATE multiplayer.session_players SET deleted_at=now(), status='archived' WHERE owner_user_id=p_user_id AND parent_id=p_session_id AND deleted_at IS NULL; END; $$;
CREATE OR REPLACE PROCEDURE journal.save_journal(p_user_id UUID, p_title TEXT, p_body TEXT, p_story_id UUID DEFAULT NULL) LANGUAGE plpgsql AS $$ BEGIN INSERT INTO journal.journal_entries(owner_user_id, story_id, name, description) VALUES (p_user_id, p_story_id, p_title, p_body); END; $$;

CREATE VIEW analytics.player_dashboard AS SELECT u.id AS user_id, u.username, u.display_name, u.is_premium, COUNT(DISTINCT s.id) AS stories_created, COUNT(DISTINCT j.id) AS journal_entries FROM auth_user.users u LEFT JOIN story.stories s ON s.owner_user_id=u.id AND s.deleted_at IS NULL LEFT JOIN journal.journal_entries j ON j.owner_user_id=u.id AND j.deleted_at IS NULL WHERE u.deleted_at IS NULL GROUP BY u.id, u.username, u.display_name, u.is_premium;
CREATE VIEW story.story_dashboard AS SELECT s.id, s.owner_user_id, s.name, s.status, COUNT(DISTINCT c.id) AS chapters, COUNT(DISTINCT sc.id) AS scenes, COUNT(DISTINCT ch.id) AS choices FROM story.stories s LEFT JOIN story.story_chapters c ON c.story_id=s.id LEFT JOIN story.story_scenes sc ON sc.story_id=s.id LEFT JOIN story.choices ch ON ch.story_id=s.id WHERE s.deleted_at IS NULL GROUP BY s.id, s.owner_user_id, s.name, s.status;
CREATE VIEW npc.npc_dashboard AS SELECT n.id, n.owner_user_id, n.world_id, n.name, COUNT(DISTINCT m.id) AS memories, COUNT(DISTINCT r.id) AS relationships FROM npc.npc_profiles n LEFT JOIN npc.npc_memories m ON m.npc_id=n.id LEFT JOIN npc.npc_relationships r ON r.npc_id=n.id WHERE n.deleted_at IS NULL GROUP BY n.id, n.owner_user_id, n.world_id, n.name;
CREATE VIEW marketplace.marketplace_dashboard AS SELECT a.id, a.name, a.owner_user_id, COUNT(t.id) AS purchases, COALESCE(SUM(t.gross_amount),0) AS gross_revenue FROM marketplace.marketplace_assets a LEFT JOIN marketplace.marketplace_transactions t ON t.asset_id=a.id AND t.status IN ('paid','settled') WHERE a.deleted_at IS NULL GROUP BY a.id, a.name, a.owner_user_id;
CREATE VIEW admin.admin_dashboard AS SELECT (SELECT COUNT(*) FROM auth_user.users WHERE deleted_at IS NULL) AS users, (SELECT COUNT(*) FROM story.stories WHERE deleted_at IS NULL) AS stories, (SELECT COUNT(*) FROM npc.npc_profiles WHERE deleted_at IS NULL) AS npcs, (SELECT COUNT(*) FROM moderation.reports WHERE deleted_at IS NULL) AS reports;

CREATE MATERIALIZED VIEW story.mv_trending_stories AS SELECT s.id, s.name, COUNT(e.id) AS event_count FROM story.stories s LEFT JOIN analytics.player_events e ON e.story_id=s.id WHERE s.deleted_at IS NULL GROUP BY s.id, s.name WITH DATA;
CREATE UNIQUE INDEX idx_mv_trending_stories_id ON story.mv_trending_stories(id);
CREATE MATERIALIZED VIEW marketplace.mv_top_marketplace_assets AS SELECT a.id, a.name, COUNT(t.id) AS purchase_count, COALESCE(SUM(t.gross_amount),0) AS revenue FROM marketplace.marketplace_assets a LEFT JOIN marketplace.marketplace_transactions t ON t.asset_id=a.id WHERE a.deleted_at IS NULL GROUP BY a.id, a.name WITH DATA;
CREATE UNIQUE INDEX idx_mv_top_marketplace_assets_id ON marketplace.mv_top_marketplace_assets(id);
CREATE MATERIALIZED VIEW analytics.mv_daily_analytics AS SELECT date_trunc('day', occurred_at) AS day, event_type, COUNT(*) AS event_count FROM analytics.player_events GROUP BY date_trunc('day', occurred_at), event_type WITH DATA;
CREATE UNIQUE INDEX idx_mv_daily_analytics_day_type ON analytics.mv_daily_analytics(day, event_type);

INSERT INTO auth_user.roles(name, slug, description, status, visibility) VALUES ('Admin', 'admin', 'Admin', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.roles(name, slug, description, status, visibility) VALUES ('Moderator', 'moderator', 'Moderator', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.roles(name, slug, description, status, visibility) VALUES ('Creator', 'creator', 'Creator', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.roles(name, slug, description, status, visibility) VALUES ('Premium User', 'premium_user', 'Premium User', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.roles(name, slug, description, status, visibility) VALUES ('Player', 'player', 'Player', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.permissions(name, slug, description, status, visibility) VALUES ('users.manage', 'users_manage', 'users.manage', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.permissions(name, slug, description, status, visibility) VALUES ('stories.publish', 'stories_publish', 'stories.publish', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.permissions(name, slug, description, status, visibility) VALUES ('moderation.review', 'moderation_review', 'moderation.review', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.permissions(name, slug, description, status, visibility) VALUES ('marketplace.sell', 'marketplace_sell', 'marketplace.sell', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.permissions(name, slug, description, status, visibility) VALUES ('analytics.view', 'analytics_view', 'analytics.view', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO auth_user.permissions(name, slug, description, status, visibility) VALUES ('ai.invoke', 'ai_invoke', 'ai.invoke', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO story.story_genres(name, slug, description, status, visibility) VALUES ('Fantasy', 'fantasy', 'Fantasy', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO story.story_genres(name, slug, description, status, visibility) VALUES ('Romance', 'romance', 'Romance', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO story.story_genres(name, slug, description, status, visibility) VALUES ('Horror', 'horror', 'Horror', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO story.story_genres(name, slug, description, status, visibility) VALUES ('Mystery', 'mystery', 'Mystery', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO story.story_genres(name, slug, description, status, visibility) VALUES ('Action', 'action', 'Action', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO story.story_genres(name, slug, description, status, visibility) VALUES ('Comedy', 'comedy', 'Comedy', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO story.story_genres(name, slug, description, status, visibility) VALUES ('Anime', 'anime', 'Anime', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO story.story_genres(name, slug, description, status, visibility) VALUES ('RPG', 'rpg', 'RPG', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO npc.npc_types(name, slug, description, status, visibility) VALUES ('Hero', 'hero', 'Hero', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO npc.npc_types(name, slug, description, status, visibility) VALUES ('Villain', 'villain', 'Villain', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO npc.npc_types(name, slug, description, status, visibility) VALUES ('Companion', 'companion', 'Companion', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO npc.npc_types(name, slug, description, status, visibility) VALUES ('Merchant', 'merchant', 'Merchant', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO npc.npc_types(name, slug, description, status, visibility) VALUES ('Quest Giver', 'quest_giver', 'Quest Giver', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO npc.npc_types(name, slug, description, status, visibility) VALUES ('Boss', 'boss', 'Boss', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.quest_types(name, slug, description, status, visibility) VALUES ('Main Quest', 'main_quest', 'Main Quest', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.quest_types(name, slug, description, status, visibility) VALUES ('Side Quest', 'side_quest', 'Side Quest', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.quest_types(name, slug, description, status, visibility) VALUES ('Daily Quest', 'daily_quest', 'Daily Quest', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.quest_types(name, slug, description, status, visibility) VALUES ('Weekly Quest', 'weekly_quest', 'Weekly Quest', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.quest_types(name, slug, description, status, visibility) VALUES ('Procedural Quest', 'procedural_quest', 'Procedural Quest', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO inventory.item_types(name, slug, description, status, visibility) VALUES ('Weapon', 'weapon', 'Weapon', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO inventory.item_types(name, slug, description, status, visibility) VALUES ('Armor', 'armor', 'Armor', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO inventory.item_types(name, slug, description, status, visibility) VALUES ('Accessory', 'accessory', 'Accessory', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO inventory.item_types(name, slug, description, status, visibility) VALUES ('Consumable', 'consumable', 'Consumable', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO inventory.item_types(name, slug, description, status, visibility) VALUES ('Magic Item', 'magic_item', 'Magic Item', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO inventory.item_types(name, slug, description, status, visibility) VALUES ('Artifact', 'artifact', 'Artifact', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO inventory.item_types(name, slug, description, status, visibility) VALUES ('Quest Item', 'quest_item', 'Quest Item', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO weather.weather_types(name, slug, description, status, visibility) VALUES ('Clear', 'clear', 'Clear', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO weather.weather_types(name, slug, description, status, visibility) VALUES ('Rain', 'rain', 'Rain', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO weather.weather_types(name, slug, description, status, visibility) VALUES ('Storm', 'storm', 'Storm', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO weather.weather_types(name, slug, description, status, visibility) VALUES ('Snow', 'snow', 'Snow', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO weather.weather_types(name, slug, description, status, visibility) VALUES ('Fog', 'fog', 'Fog', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO weather.weather_types(name, slug, description, status, visibility) VALUES ('Heatwave', 'heatwave', 'Heatwave', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO marketplace.marketplace_categories(name, slug, description, status, visibility) VALUES ('World Packs', 'world_packs', 'World Packs', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO marketplace.marketplace_categories(name, slug, description, status, visibility) VALUES ('Story Packs', 'story_packs', 'Story Packs', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO marketplace.marketplace_categories(name, slug, description, status, visibility) VALUES ('NPC Packs', 'npc_packs', 'NPC Packs', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO marketplace.marketplace_categories(name, slug, description, status, visibility) VALUES ('Voice Packs', 'voice_packs', 'Voice Packs', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO marketplace.marketplace_categories(name, slug, description, status, visibility) VALUES ('Character Skins', 'character_skins', 'Character Skins', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO marketplace.marketplace_categories(name, slug, description, status, visibility) VALUES ('Visual Themes', 'visual_themes', 'Visual Themes', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO marketplace.marketplace_categories(name, slug, description, status, visibility) VALUES ('Quest Packs', 'quest_packs', 'Quest Packs', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO subscription.subscription_plans(name, slug, description, status, visibility) VALUES ('Free', 'free', 'Free', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO subscription.subscription_plans(name, slug, description, status, visibility) VALUES ('Pro', 'pro', 'Pro', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO subscription.subscription_plans(name, slug, description, status, visibility) VALUES ('Creator', 'creator', 'Creator', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.achievement_categories(name, slug, description, status, visibility) VALUES ('Story', 'story', 'Story', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.achievement_categories(name, slug, description, status, visibility) VALUES ('Quest', 'quest', 'Quest', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.achievement_categories(name, slug, description, status, visibility) VALUES ('Combat', 'combat', 'Combat', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.achievement_categories(name, slug, description, status, visibility) VALUES ('Creator', 'creator', 'Creator', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.achievement_categories(name, slug, description, status, visibility) VALUES ('Marketplace', 'marketplace', 'Marketplace', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO progression.achievement_categories(name, slug, description, status, visibility) VALUES ('Social', 'social', 'Social', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO notification.notification_types(name, slug, description, status, visibility) VALUES ('System', 'system', 'System', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO notification.notification_types(name, slug, description, status, visibility) VALUES ('Story', 'story', 'Story', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO notification.notification_types(name, slug, description, status, visibility) VALUES ('Quest', 'quest', 'Quest', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO notification.notification_types(name, slug, description, status, visibility) VALUES ('Marketplace', 'marketplace', 'Marketplace', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO notification.notification_types(name, slug, description, status, visibility) VALUES ('Guild', 'guild', 'Guild', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO notification.notification_types(name, slug, description, status, visibility) VALUES ('Friend', 'friend', 'Friend', 'active', 'public') ON CONFLICT DO NOTHING;
INSERT INTO notification.notification_types(name, slug, description, status, visibility) VALUES ('Billing', 'billing', 'Billing', 'active', 'public') ON CONFLICT DO NOTHING;

CREATE ROLE lucid_app NOINHERIT;
CREATE ROLE lucid_readonly NOINHERIT;
CREATE ROLE lucid_admin NOINHERIT;
GRANT USAGE ON SCHEMA auth_user, world, story, npc, ai, media, inventory, combat, progression, economy, politics, weather, transportation, business, guild, marketplace, creator, journal, recommendation, analytics, moderation, notification, multiplayer, social, subscription, admin, audit, history, system TO lucid_app, lucid_readonly, lucid_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA auth_user, world, story, npc, ai, media, inventory, combat, progression, economy, politics, weather, transportation, business, guild, marketplace, creator, journal, recommendation, analytics, moderation, notification, multiplayer, social, subscription, admin, audit, history, system TO lucid_readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth_user, world, story, npc, ai, media, inventory, combat, progression, economy, politics, weather, transportation, business, guild, marketplace, creator, journal, recommendation, analytics, moderation, notification, multiplayer, social, subscription, admin, system TO lucid_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth_user, world, story, npc, ai, media, inventory, combat, progression, economy, politics, weather, transportation, business, guild, marketplace, creator, journal, recommendation, analytics, moderation, notification, multiplayer, social, subscription, admin, audit, history, system TO lucid_admin;
ALTER TABLE auth_user.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS users_self_or_public ON auth_user.users;
CREATE POLICY users_self_or_public ON auth_user.users FOR SELECT USING (id::text = current_setting('app.current_user_id', true) OR deleted_at IS NULL);
ALTER TABLE notification.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notifications_owner ON notification.notifications;
CREATE POLICY notifications_owner ON notification.notifications FOR SELECT USING (user_id::text = current_setting('app.current_user_id', true));

CREATE OR REPLACE PROCEDURE system.refresh_materialized_views() LANGUAGE plpgsql AS $$ BEGIN REFRESH MATERIALIZED VIEW CONCURRENTLY story.mv_trending_stories; REFRESH MATERIALIZED VIEW CONCURRENTLY marketplace.mv_top_marketplace_assets; REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_daily_analytics; END; $$;
CREATE OR REPLACE PROCEDURE system.partition_maintenance() LANGUAGE plpgsql AS $$ BEGIN PERFORM system.create_monthly_partitions('audit.audit_logs'::regclass, 'occurred_at', 36); PERFORM system.create_monthly_partitions('history.entity_history'::regclass, 'changed_at', 36); PERFORM system.create_monthly_partitions('analytics.player_events'::regclass, 'occurred_at', 36); PERFORM system.create_monthly_partitions('notification.notifications'::regclass, 'created_at', 36); PERFORM system.create_monthly_partitions('ai.ai_request_logs'::regclass, 'created_at', 36); PERFORM system.create_monthly_partitions('ai.conversation_history_events'::regclass, 'created_at', 36); PERFORM system.create_monthly_partitions('marketplace.marketplace_transactions'::regclass, 'created_at', 36); PERFORM system.create_monthly_partitions('system.system_logs'::regclass, 'created_at', 36); END; $$;
CREATE OR REPLACE PROCEDURE system.database_maintenance() LANGUAGE plpgsql AS $$ BEGIN CALL system.partition_maintenance(); CALL system.refresh_materialized_views(); END; $$;
COMMIT;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS ai;
CREATE SCHEMA IF NOT EXISTS media;
CREATE SCHEMA IF NOT EXISTS system;
CREATE SCHEMA IF NOT EXISTS npc;
CREATE SCHEMA IF NOT EXISTS world_simulation;
CREATE SCHEMA IF NOT EXISTS subscription;
CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS app.website_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    route_path TEXT NOT NULL UNIQUE,
    module_name TEXT NOT NULL,
    requires_auth BOOLEAN NOT NULL DEFAULT true,
    requires_premium BOOLEAN NOT NULL DEFAULT false,
    requires_creator BOOLEAN NOT NULL DEFAULT false,
    requires_admin BOOLEAN NOT NULL DEFAULT false,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    search_document TSVECTOR,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_website_pages_module ON app.website_pages(module_name);
CREATE INDEX IF NOT EXISTS idx_website_pages_metadata_gin ON app.website_pages USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_website_pages_search_gin ON app.website_pages USING gin(search_document);

CREATE TABLE IF NOT EXISTS system.service_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    service_type TEXT NOT NULL CHECK (service_type IN ('frontend','gateway','domain_service','ai_orchestrator','ai_module','database','cache','storage','vector_store','external_api')),
    endpoint TEXT,
    healthcheck_path TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','degraded','retired')),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS system.service_dependencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id UUID NOT NULL REFERENCES system.service_registry(id) ON DELETE CASCADE,
    depends_on_service_id UUID NOT NULL REFERENCES system.service_registry(id) ON DELETE CASCADE,
    dependency_kind TEXT NOT NULL DEFAULT 'runtime',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ,
    UNIQUE(service_id, depends_on_service_id)
);

CREATE INDEX IF NOT EXISTS idx_service_dependencies_service ON system.service_dependencies(service_id);
CREATE INDEX IF NOT EXISTS idx_service_dependencies_depends ON system.service_dependencies(depends_on_service_id);
CREATE INDEX IF NOT EXISTS idx_service_registry_metadata_gin ON system.service_registry USING gin(metadata);

CREATE TABLE IF NOT EXISTS ai.ai_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    module_type TEXT NOT NULL CHECK (module_type IN ('story','npc','memory','emotion','recommendation','quest','world','image','voice','music','cinematic')),
    model_provider TEXT,
    default_model TEXT,
    input_contract JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_contract JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_stateful BOOLEAN NOT NULL DEFAULT false,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','deprecated')),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    embedding vector(1536),
    search_document TSVECTOR,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ai.ai_orchestrator_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    story_id UUID,
    world_id UUID,
    npc_id UUID,
    quest_id UUID,
    run_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','succeeded','failed','cancelled')),
    requested_modules TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    input_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    error_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ai.ai_module_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    orchestrator_run_id UUID REFERENCES ai.ai_orchestrator_runs(id) ON DELETE CASCADE,
    ai_module_id UUID REFERENCES ai.ai_modules(id),
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','succeeded','failed','cancelled')),
    sequence_number INT NOT NULL DEFAULT 1 CHECK (sequence_number > 0),
    input_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    token_usage JSONB NOT NULL DEFAULT '{}'::jsonb,
    cost_amount NUMERIC(20,6) NOT NULL DEFAULT 0 CHECK (cost_amount >= 0),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ai.image_generation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    story_id UUID,
    world_id UUID,
    npc_id UUID,
    asset_id UUID,
    image_category TEXT NOT NULL CHECK (image_category IN ('character_portrait','city','forest','monster','weapon','building','vehicle','space_ship','magical_scene','scene_artwork')),
    prompt TEXT NOT NULL,
    negative_prompt TEXT,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','succeeded','failed','cancelled')),
    output_uri TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    embedding vector(1536),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ai.voice_generation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    npc_id UUID,
    conversation_id UUID,
    voice_profile_id UUID,
    text_input TEXT NOT NULL,
    emotion_label TEXT,
    accent_label TEXT,
    age_label TEXT,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','succeeded','failed','cancelled')),
    output_uri TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ai.cinematic_generation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    story_id UUID,
    world_id UUID,
    scene_id UUID,
    cinematic_type TEXT NOT NULL DEFAULT 'major_scene',
    duration_seconds INT NOT NULL DEFAULT 10 CHECK (duration_seconds BETWEEN 1 AND 120),
    prompt TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','succeeded','failed','cancelled')),
    output_uri TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS media.cinematic_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    story_id UUID,
    scene_id UUID,
    name TEXT NOT NULL,
    asset_uri TEXT NOT NULL,
    duration_seconds INT CHECK (duration_seconds IS NULL OR duration_seconds > 0),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    search_document TSVECTOR,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS npc.relationship_interaction_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    interaction_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    relationship_delta NUMERIC(8,3) NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS npc.relationship_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID,
    npc_id UUID,
    target_npc_id UUID,
    interaction_type_id UUID REFERENCES npc.relationship_interaction_types(id),
    story_id UUID,
    world_id UUID,
    description TEXT,
    relationship_delta NUMERIC(8,3) NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS world_simulation.crime_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    world_id UUID,
    region_id UUID,
    city_id UUID,
    event_type TEXT NOT NULL,
    severity NUMERIC(6,3) NOT NULL DEFAULT 0 CHECK (severity BETWEEN 0 AND 100),
    description TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS world_simulation.population_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    world_id UUID NOT NULL,
    region_id UUID,
    city_id UUID,
    population_count BIGINT NOT NULL CHECK (population_count >= 0),
    birth_rate NUMERIC(10,6),
    death_rate NUMERIC(10,6),
    migration_rate NUMERIC(10,6),
    demographics JSONB NOT NULL DEFAULT '{}'::jsonb,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS subscription.plan_feature_entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_key TEXT NOT NULL,
    feature_key TEXT NOT NULL,
    feature_name TEXT NOT NULL,
    limit_value NUMERIC(20,6),
    is_unlimited BOOLEAN NOT NULL DEFAULT false,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    updated_by UUID,
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ,
    UNIQUE(plan_key, feature_key)
);

CREATE INDEX IF NOT EXISTS idx_ai_modules_type ON ai.ai_modules(module_type);
CREATE INDEX IF NOT EXISTS idx_ai_modules_metadata_gin ON ai.ai_modules USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_ai_modules_search_gin ON ai.ai_modules USING gin(search_document);
CREATE INDEX IF NOT EXISTS idx_ai_modules_embedding_hnsw ON ai.ai_modules USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_ai_modules_embedding_ivfflat ON ai.ai_modules USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_ai_orchestrator_runs_owner ON ai.ai_orchestrator_runs(owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_orchestrator_runs_payload_gin ON ai.ai_orchestrator_runs USING gin(input_payload);
CREATE INDEX IF NOT EXISTS idx_ai_module_runs_orchestrator ON ai.ai_module_runs(orchestrator_run_id, sequence_number);
CREATE INDEX IF NOT EXISTS idx_ai_module_runs_module ON ai.ai_module_runs(ai_module_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_module_runs_payload_gin ON ai.ai_module_runs USING gin(output_payload);
CREATE INDEX IF NOT EXISTS idx_image_generation_jobs_owner ON ai.image_generation_jobs(owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_image_generation_jobs_embedding_hnsw ON ai.image_generation_jobs USING hnsw (embedding vector_cosine_ops);
CREATE INDEX IF NOT EXISTS idx_voice_generation_jobs_npc ON ai.voice_generation_jobs(npc_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cinematic_generation_jobs_story ON ai.cinematic_generation_jobs(story_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cinematic_assets_search_gin ON media.cinematic_assets USING gin(search_document);
CREATE INDEX IF NOT EXISTS idx_relationship_interactions_npc ON npc.relationship_interactions(npc_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_relationship_interactions_metadata_gin ON npc.relationship_interactions USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_crime_events_world_time ON world_simulation.crime_events(world_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_crime_events_metadata_gin ON world_simulation.crime_events USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_population_snapshots_world_time ON world_simulation.population_snapshots(world_id, measured_at DESC);
CREATE INDEX IF NOT EXISTS idx_population_snapshots_demographics_gin ON world_simulation.population_snapshots USING gin(demographics);
CREATE INDEX IF NOT EXISTS idx_plan_feature_entitlements_plan ON subscription.plan_feature_entitlements(plan_key);
CREATE INDEX IF NOT EXISTS idx_plan_feature_entitlements_metadata_gin ON subscription.plan_feature_entitlements USING gin(metadata);

CREATE OR REPLACE FUNCTION app.update_website_pages_search_document()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.search_document := to_tsvector('english', COALESCE(NEW.name,'') || ' ' || COALESCE(NEW.page_key,'') || ' ' || COALESCE(NEW.module_name,'') || ' ' || COALESCE(NEW.metadata::text,''));
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION ai.update_ai_modules_search_document()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.search_document := to_tsvector('english', COALESCE(NEW.name,'') || ' ' || COALESCE(NEW.module_key,'') || ' ' || COALESCE(NEW.module_type,'') || ' ' || COALESCE(NEW.metadata::text,''));
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION media.update_cinematic_assets_search_document()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.search_document := to_tsvector('english', COALESCE(NEW.name,'') || ' ' || COALESCE(NEW.metadata::text,''));
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_website_pages_search ON app.website_pages;
CREATE TRIGGER trg_website_pages_search BEFORE INSERT OR UPDATE ON app.website_pages FOR EACH ROW EXECUTE FUNCTION app.update_website_pages_search_document();
DROP TRIGGER IF EXISTS trg_ai_modules_search ON ai.ai_modules;
CREATE TRIGGER trg_ai_modules_search BEFORE INSERT OR UPDATE ON ai.ai_modules FOR EACH ROW EXECUTE FUNCTION ai.update_ai_modules_search_document();
DROP TRIGGER IF EXISTS trg_cinematic_assets_search ON media.cinematic_assets;
CREATE TRIGGER trg_cinematic_assets_search BEFORE INSERT OR UPDATE ON media.cinematic_assets FOR EACH ROW EXECUTE FUNCTION media.update_cinematic_assets_search_document();

CREATE OR REPLACE PROCEDURE ai.enqueue_orchestrator_run(
    p_owner_user_id UUID,
    p_run_key TEXT,
    p_requested_modules TEXT[],
    p_input_payload JSONB DEFAULT '{}'::jsonb
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO ai.ai_orchestrator_runs(owner_user_id, run_key, requested_modules, input_payload)
    VALUES (p_owner_user_id, p_run_key, p_requested_modules, p_input_payload);
END;
$$;

CREATE OR REPLACE PROCEDURE ai.enqueue_image_generation(
    p_owner_user_id UUID,
    p_image_category TEXT,
    p_prompt TEXT,
    p_story_id UUID DEFAULT NULL,
    p_world_id UUID DEFAULT NULL,
    p_npc_id UUID DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO ai.image_generation_jobs(owner_user_id, image_category, prompt, story_id, world_id, npc_id)
    VALUES (p_owner_user_id, p_image_category, p_prompt, p_story_id, p_world_id, p_npc_id);
END;
$$;

INSERT INTO app.website_pages(page_key, name, route_path, module_name, requires_auth, requires_premium, requires_creator, requires_admin)
VALUES
('landing_page','Landing Page','/','website',false,false,false,false),
('sign_up','Sign Up','/signup','auth',false,false,false,false),
('login','Login','/login','auth',false,false,false,false),
('dashboard','Dashboard','/dashboard','player',true,false,false,false),
('story_screen','Story Screen','/story','story',true,false,false,false),
('character_profile','Character Profile','/character','npc',true,false,false,false),
('npc_encyclopedia','NPC Encyclopedia','/npc-encyclopedia','npc',true,false,false,false),
('world_map','World Map','/world-map','world',true,false,false,false),
('quest_journal','Quest Journal','/quest-journal','quest',true,false,false,false),
('inventory','Inventory','/inventory','inventory',true,false,false,false),
('timeline','Timeline','/timeline','story',true,false,false,false),
('gallery','Gallery','/gallery','media',true,false,false,false),
('notifications','Notifications','/notifications','notification',true,false,false,false),
('ai_settings','AI Settings','/settings/ai','ai',true,false,false,false),
('premium','Premium','/premium','subscription',true,false,false,false),
('creator_studio','Creator Studio','/creator','creator',true,false,true,false),
('marketplace','Marketplace','/marketplace','marketplace',true,false,false,false),
('admin_panel','Admin Panel','/admin','admin',true,false,false,true)
ON CONFLICT (page_key) DO NOTHING;

INSERT INTO system.service_registry(service_key, name, service_type)
VALUES
('nextjs_website','Next.js Website','frontend'),
('api_gateway','API Gateway','gateway'),
('story_service','Story Service','domain_service'),
('memory_service','Memory Service','domain_service'),
('npc_service','NPC Service','domain_service'),
('world_service','World Service','domain_service'),
('quest_service','Quest Service','domain_service'),
('ai_orchestrator','AI Orchestrator','ai_orchestrator'),
('postgresql_database','PostgreSQL Database','database'),
('qdrant_vector_store','Qdrant Vector Store','vector_store'),
('redis_cache','Redis Cache','cache'),
('object_storage','Object Storage','storage')
ON CONFLICT (service_key) DO NOTHING;

INSERT INTO ai.ai_modules(module_key, name, module_type, is_stateful)
VALUES
('story_ai','Story AI','story',true),
('npc_ai','NPC AI','npc',true),
('memory_ai','Memory AI','memory',true),
('emotion_ai','Emotion AI','emotion',true),
('recommendation_ai','Recommendation AI','recommendation',true),
('quest_ai','Quest AI','quest',true),
('world_ai','World AI','world',true),
('image_ai','Image AI','image',false),
('voice_ai','Voice AI','voice',false),
('music_ai','Music AI','music',false),
('cinematic_ai','Cinematic AI','cinematic',false)
ON CONFLICT (module_key) DO NOTHING;

INSERT INTO npc.relationship_interaction_types(interaction_key, name, relationship_delta)
VALUES
('gift','Gift',5),
('betrayal','Betrayal',-25),
('conversation','Conversation',1),
('fight','Fight',-10),
('promise','Promise',3),
('marriage','Marriage',30),
('friendship','Friendship',15)
ON CONFLICT (interaction_key) DO NOTHING;

INSERT INTO subscription.plan_feature_entitlements(plan_key, feature_key, feature_name, limit_value, is_unlimited)
VALUES
('free','chapters_per_day','Chapters Per Day',10,false),
('free','worlds','Worlds',3,false),
('free','limited_artwork','Limited Artwork',1,false),
('pro','stories','Unlimited Stories',NULL,true),
('pro','premium_ai_models','Premium AI Models',NULL,true),
('pro','voice_conversations','Voice Conversations',NULL,true),
('pro','cinematic_scenes','Cinematic Scenes',NULL,true),
('pro','long_term_memory','Long-term Memory',NULL,true),
('future','creator_marketplace','Creator Marketplace',NULL,true),
('future','world_subscriptions','World Subscriptions',NULL,true),
('future','premium_story_packs','Premium Story Packs',NULL,true),
('future','creator_skins','Creator Skins',NULL,true),
('future','visual_themes','Visual Themes',NULL,true)
ON CONFLICT (plan_key, feature_key) DO NOTHING;

ALTER TABLE app.website_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.service_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE system.service_dependencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai.ai_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai.ai_orchestrator_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai.ai_module_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai.image_generation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai.voice_generation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai.cinematic_generation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE media.cinematic_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE npc.relationship_interaction_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE npc.relationship_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE world_simulation.crime_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE world_simulation.population_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription.plan_feature_entitlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY website_pages_public_read ON app.website_pages FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY ai_modules_public_read ON ai.ai_modules FOR SELECT USING (deleted_at IS NULL AND status = 'active');
CREATE POLICY relationship_interaction_types_read ON npc.relationship_interaction_types FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY plan_feature_entitlements_read ON subscription.plan_feature_entitlements FOR SELECT USING (deleted_at IS NULL);

COMMENT ON TABLE app.website_pages IS 'Architecture gap delta: first-class registry for website pages shown in the LUCID AI architecture.';
COMMENT ON TABLE system.service_registry IS 'Architecture gap delta: service topology including website, API gateway, services, orchestrator, database, vector store, cache, and storage.';
COMMENT ON TABLE ai.ai_modules IS 'Architecture gap delta: explicit AI module catalog for Story AI, NPC AI, Memory AI, Emotion AI, Recommendation AI, Quest AI, World AI, Image AI, Voice AI, Music AI, and Cinematic AI.';
COMMENT ON TABLE ai.ai_orchestrator_runs IS 'Architecture gap delta: AI orchestrator execution tracking across platform AI modules.';
COMMENT ON TABLE ai.image_generation_jobs IS 'Architecture gap delta: AI image generation jobs for portraits, cities, monsters, weapons, buildings, vehicles, spaceships, and magical scenes.';
COMMENT ON TABLE ai.voice_generation_jobs IS 'Architecture gap delta: AI voice generation jobs for NPC speech, voices, ages, accents, and emotions.';
COMMENT ON TABLE ai.cinematic_generation_jobs IS 'Architecture gap delta: AI cinematic generation jobs for major scenes and short cinematic videos.';
COMMENT ON TABLE npc.relationship_interaction_types IS 'Architecture gap delta: relationship interaction taxonomy for gifts, betrayals, conversations, fights, promises, marriage, and friendship.';
COMMENT ON TABLE world_simulation.crime_events IS 'Architecture gap delta: world simulation support for crime events.';
COMMENT ON TABLE world_simulation.population_snapshots IS 'Architecture gap delta: world simulation support for population statistics.';

CREATE SCHEMA IF NOT EXISTS backup;
CREATE SCHEMA IF NOT EXISTS monitoring;
CREATE SCHEMA IF NOT EXISTS search;
CREATE SCHEMA IF NOT EXISTS crafting;

CREATE TABLE IF NOT EXISTS backup.backup_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    backup_name TEXT NOT NULL UNIQUE,
    backup_type TEXT NOT NULL CHECK (backup_type IN ('full','incremental','differential','logical','physical')),
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','running','completed','failed','expired')),
    storage_uri TEXT,
    checksum TEXT,
    size_bytes BIGINT CHECK (size_bytes IS NULL OR size_bytes >= 0),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    requested_by UUID REFERENCES auth_user.users(id),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS backup.restore_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    backup_id UUID REFERENCES backup.backup_metadata(id),
    restore_name TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','running','completed','failed','cancelled')),
    target_environment TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    requested_by UUID REFERENCES auth_user.users(id),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS backup.backup_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    backup_id UUID REFERENCES backup.backup_metadata(id),
    event_type TEXT NOT NULL,
    event_message TEXT,
    event_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS backup.recovery_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restore_id UUID REFERENCES backup.restore_metadata(id),
    event_type TEXT NOT NULL,
    event_message TEXT,
    event_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS monitoring.performance_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name TEXT NOT NULL,
    metric_value NUMERIC(30,8) NOT NULL,
    metric_unit TEXT,
    dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS monitoring.slow_query_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query_hash TEXT NOT NULL,
    query_text TEXT NOT NULL,
    duration_ms NUMERIC(20,3) NOT NULL CHECK (duration_ms >= 0),
    rows_returned BIGINT,
    database_name TEXT,
    username TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS monitoring.storage_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    total_bytes BIGINT NOT NULL CHECK (total_bytes >= 0),
    table_bytes BIGINT NOT NULL CHECK (table_bytes >= 0),
    index_bytes BIGINT NOT NULL CHECK (index_bytes >= 0),
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS monitoring.index_usage_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    index_name TEXT NOT NULL,
    idx_scan BIGINT NOT NULL DEFAULT 0,
    idx_tup_read BIGINT NOT NULL DEFAULT 0,
    idx_tup_fetch BIGINT NOT NULL DEFAULT 0,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS monitoring.cache_statistics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cache_name TEXT NOT NULL,
    hits BIGINT NOT NULL DEFAULT 0,
    misses BIGINT NOT NULL DEFAULT 0,
    evictions BIGINT NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS monitoring.ai_usage_statistics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT,
    model TEXT,
    prompt_tokens BIGINT NOT NULL DEFAULT 0,
    completion_tokens BIGINT NOT NULL DEFAULT 0,
    total_cost NUMERIC(20,6) NOT NULL DEFAULT 0,
    request_count BIGINT NOT NULL DEFAULT 0,
    error_count BIGINT NOT NULL DEFAULT 0,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS monitoring.revenue_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revenue_source TEXT NOT NULL,
    gross_amount NUMERIC(20,6) NOT NULL DEFAULT 0,
    net_amount NUMERIC(20,6) NOT NULL DEFAULT 0,
    currency_code TEXT NOT NULL DEFAULT 'USD',
    dimensions JSONB NOT NULL DEFAULT '{}'::jsonb,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS monitoring.system_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    component TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('healthy','degraded','down','unknown')),
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES auth_user.users(id),
    updated_by UUID REFERENCES auth_user.users(id),
    version BIGINT NOT NULL DEFAULT 1,
    deleted_at TIMESTAMPTZ
);

SELECT system.create_lucid_entity_table('crafting', 'recipes');
SELECT system.create_lucid_entity_table('crafting', 'materials');
SELECT system.create_lucid_entity_table('crafting', 'crafting_stations');
SELECT system.create_lucid_entity_table('crafting', 'enchantments');
SELECT system.create_lucid_entity_table('crafting', 'blueprints');
SELECT system.create_lucid_entity_table('crafting', 'crafting_history');

CREATE INDEX IF NOT EXISTS idx_backup_metadata_status ON backup.backup_metadata(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_restore_metadata_status ON backup.restore_metadata(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_backup_history_data_gin ON backup.backup_history USING gin(event_data);
CREATE INDEX IF NOT EXISTS idx_recovery_history_data_gin ON backup.recovery_history USING gin(event_data);
CREATE INDEX IF NOT EXISTS idx_monitoring_performance_name_time ON monitoring.performance_metrics(metric_name, measured_at DESC);
CREATE INDEX IF NOT EXISTS idx_monitoring_performance_dimensions_gin ON monitoring.performance_metrics USING gin(dimensions);
CREATE INDEX IF NOT EXISTS idx_monitoring_slow_query_hash ON monitoring.slow_query_logs(query_hash, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_monitoring_slow_query_metadata_gin ON monitoring.slow_query_logs USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_monitoring_storage_table ON monitoring.storage_metrics(schema_name, table_name, measured_at DESC);
CREATE INDEX IF NOT EXISTS idx_monitoring_index_usage_table ON monitoring.index_usage_metrics(schema_name, table_name, index_name, measured_at DESC);
CREATE INDEX IF NOT EXISTS idx_monitoring_cache_metadata_gin ON monitoring.cache_statistics USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_monitoring_revenue_dimensions_gin ON monitoring.revenue_metrics USING gin(dimensions);
CREATE INDEX IF NOT EXISTS idx_monitoring_system_health_component ON monitoring.system_health(component, checked_at DESC);

CREATE OR REPLACE FUNCTION search.rank_full_text(p_document TSVECTOR, p_query TEXT)
RETURNS REAL
LANGUAGE sql
STABLE
AS $$
    SELECT ts_rank_cd(p_document, plainto_tsquery('english', p_query));
$$;

CREATE OR REPLACE FUNCTION search.cosine_distance(p_left vector, p_right vector)
RETURNS DOUBLE PRECISION
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT p_left <=> p_right;
$$;

CREATE OR REPLACE FUNCTION search.cosine_similarity(p_left vector, p_right vector)
RETURNS DOUBLE PRECISION
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT 1 - (p_left <=> p_right);
$$;

CREATE OR REPLACE PROCEDURE backup.request_backup(
    p_backup_name TEXT,
    p_backup_type TEXT,
    p_requested_by UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_backup_id UUID;
BEGIN
    INSERT INTO backup.backup_metadata(backup_name, backup_type, status, requested_by, metadata, started_at)
    VALUES (p_backup_name, p_backup_type, 'requested', p_requested_by, p_metadata, now())
    RETURNING id INTO v_backup_id;

    INSERT INTO backup.backup_history(backup_id, event_type, event_message)
    VALUES (v_backup_id, 'requested', 'Backup requested');
END;
$$;

CREATE OR REPLACE PROCEDURE backup.request_restore(
    p_backup_id UUID,
    p_restore_name TEXT,
    p_target_environment TEXT,
    p_requested_by UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_restore_id UUID;
BEGIN
    INSERT INTO backup.restore_metadata(backup_id, restore_name, status, target_environment, requested_by, metadata, started_at)
    VALUES (p_backup_id, p_restore_name, 'requested', p_target_environment, p_requested_by, p_metadata, now())
    RETURNING id INTO v_restore_id;

    INSERT INTO backup.recovery_history(restore_id, event_type, event_message)
    VALUES (v_restore_id, 'requested', 'Restore requested');
END;
$$;

CREATE OR REPLACE PROCEDURE monitoring.capture_storage_metrics()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO monitoring.storage_metrics(schema_name, table_name, total_bytes, table_bytes, index_bytes)
    SELECT
        schemaname,
        tablename,
        pg_total_relation_size(format('%I.%I', schemaname, tablename)::regclass),
        pg_relation_size(format('%I.%I', schemaname, tablename)::regclass),
        pg_indexes_size(format('%I.%I', schemaname, tablename)::regclass)
    FROM pg_tables
    WHERE schemaname NOT IN ('pg_catalog','information_schema');
END;
$$;

CREATE MATERIALIZED VIEW IF NOT EXISTS monitoring.mv_daily_ai_usage AS
SELECT
    date_trunc('day', measured_at) AS metric_day,
    COALESCE(provider, 'unknown') AS provider,
    COALESCE(model, 'unknown') AS model,
    SUM(prompt_tokens) AS prompt_tokens,
    SUM(completion_tokens) AS completion_tokens,
    SUM(total_cost) AS total_cost,
    SUM(request_count) AS request_count,
    SUM(error_count) AS error_count
FROM monitoring.ai_usage_statistics
GROUP BY date_trunc('day', measured_at), COALESCE(provider, 'unknown'), COALESCE(model, 'unknown')
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_ai_usage ON monitoring.mv_daily_ai_usage(metric_day, provider, model);

CREATE MATERIALIZED VIEW IF NOT EXISTS monitoring.mv_daily_revenue AS
SELECT
    date_trunc('day', measured_at) AS metric_day,
    revenue_source,
    currency_code,
    SUM(gross_amount) AS gross_amount,
    SUM(net_amount) AS net_amount
FROM monitoring.revenue_metrics
GROUP BY date_trunc('day', measured_at), revenue_source, currency_code
WITH DATA;

CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_daily_revenue ON monitoring.mv_daily_revenue(metric_day, revenue_source, currency_code);

CREATE OR REPLACE PROCEDURE system.refresh_all_production_materialized_views()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL system.refresh_all_materialized_views();
    REFRESH MATERIALIZED VIEW CONCURRENTLY monitoring.mv_daily_ai_usage;
    REFRESH MATERIALIZED VIEW CONCURRENTLY monitoring.mv_daily_revenue;
END;
$$;

INSERT INTO crafting.materials(name, slug, description, status, visibility)
VALUES
('Wood','wood','Wood crafting material','active','public'),
('Iron','iron','Iron crafting material','active','public'),
('Crystal','crystal','Crystal crafting material','active','public'),
('Leather','leather','Leather crafting material','active','public'),
('Herb','herb','Herb crafting material','active','public'),
('Rune','rune','Rune crafting material','active','public'),
('Essence','essence','Essence crafting material','active','public')
ON CONFLICT DO NOTHING;

GRANT USAGE ON SCHEMA backup, monitoring, search, crafting TO lucid_app, lucid_readonly, lucid_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA backup, monitoring, search, crafting TO lucid_readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA backup, monitoring, crafting TO lucid_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA search TO lucid_app, lucid_readonly, lucid_admin;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA backup, monitoring, system TO lucid_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA backup, monitoring, search, crafting TO lucid_admin;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT n.nspname, c.relname, obj_description(c.oid, 'pg_class') AS existing_comment
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('r','p','v','m')
          AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
    LOOP
        IF r.existing_comment IS NULL THEN
            EXECUTE format('COMMENT ON TABLE %I.%I IS %L', r.nspname, r.relname, 'LUCID AI production database object: ' || r.nspname || '.' || r.relname);
        END IF;
    END LOOP;

    FOR r IN
        SELECT n.nspname, c.relname, a.attname, col_description(c.oid, a.attnum) AS existing_comment
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a ON a.attrelid = c.oid
        WHERE c.relkind IN ('r','p','v','m')
          AND a.attnum > 0
          AND NOT a.attisdropped
          AND n.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
    LOOP
        IF r.existing_comment IS NULL THEN
            EXECUTE format('COMMENT ON COLUMN %I.%I.%I IS %L', r.nspname, r.relname, r.attname, 'LUCID AI column: ' || r.attname);
        END IF;
    END LOOP;
END $$;

COMMENT ON FUNCTION search.rank_full_text(TSVECTOR, TEXT) IS 'Ranks LUCID AI full-text search results.';
COMMENT ON FUNCTION search.cosine_distance(vector, vector) IS 'Returns pgvector cosine distance for LUCID AI semantic search.';
COMMENT ON FUNCTION search.cosine_similarity(vector, vector) IS 'Returns pgvector cosine similarity for LUCID AI semantic search.';
COMMENT ON PROCEDURE backup.request_backup(TEXT, TEXT, UUID, JSONB) IS 'Registers a LUCID AI backup request.';
COMMENT ON PROCEDURE backup.request_restore(UUID, TEXT, TEXT, UUID, JSONB) IS 'Registers a LUCID AI restore request.';
COMMENT ON PROCEDURE monitoring.capture_storage_metrics() IS 'Captures LUCID AI storage metrics.';
COMMENT ON PROCEDURE system.refresh_all_production_materialized_views() IS 'Refreshes all LUCID AI production materialized views.';
