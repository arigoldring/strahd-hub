export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      campaign_fortunes: {
        Row: {
          campaign_id: string
          card: number
          created_at: string
          id: string
          is_found: boolean
          is_revealed: boolean
          lines: string[]
          title: string
        }
        Insert: {
          campaign_id: string
          card: number
          created_at?: string
          id?: string
          is_found?: boolean
          is_revealed?: boolean
          lines: string[]
          title: string
        }
        Update: {
          campaign_id?: string
          card?: number
          created_at?: string
          id?: string
          is_found?: boolean
          is_revealed?: boolean
          lines?: string[]
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "campaign_fortunes_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      campaign_map_reveals: {
        Row: {
          campaign_id: string
          is_revealed: boolean
          map_key: string
        }
        Insert: {
          campaign_id: string
          is_revealed: boolean
          map_key: string
        }
        Update: {
          campaign_id?: string
          is_revealed?: boolean
          map_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "campaign_map_reveals_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      campaign_members: {
        Row: {
          campaign_id: string
          role: string
          user_id: string
        }
        Insert: {
          campaign_id: string
          role?: string
          user_id: string
        }
        Update: {
          campaign_id?: string
          role?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "campaign_members_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "campaign_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      campaigns: {
        Row: {
          created_at: string
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
      character_classes: {
        Row: {
          character_id: string
          class_id: string
          created_at: string
          fighting_style: string | null
          id: string
          is_starting: boolean
          level: number
          subclass_id: string | null
        }
        Insert: {
          character_id: string
          class_id: string
          created_at?: string
          fighting_style?: string | null
          id?: string
          is_starting?: boolean
          level?: number
          subclass_id?: string | null
        }
        Update: {
          character_id?: string
          class_id?: string
          created_at?: string
          fighting_style?: string | null
          id?: string
          is_starting?: boolean
          level?: number
          subclass_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "character_classes_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_classes_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_classes_subclass_id_class_id_fkey"
            columns: ["subclass_id", "class_id"]
            isOneToOne: false
            referencedRelation: "subclasses"
            referencedColumns: ["id", "class_id"]
          },
        ]
      }
      character_feats: {
        Row: {
          character_id: string
          created_at: string
          feat_id: string
          id: string
        }
        Insert: {
          character_id: string
          created_at?: string
          feat_id: string
          id?: string
        }
        Update: {
          character_id?: string
          created_at?: string
          feat_id?: string
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_feats_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_feats_feat_id_fkey"
            columns: ["feat_id"]
            isOneToOne: false
            referencedRelation: "feats"
            referencedColumns: ["id"]
          },
        ]
      }
      character_feature_choices: {
        Row: {
          character_class_id: string
          character_id: string
          class_id: string
          created_at: string
          detail: string | null
          feature_id: string
          id: string
          option_id: string
        }
        Insert: {
          character_class_id: string
          character_id: string
          class_id: string
          created_at?: string
          detail?: string | null
          feature_id: string
          id?: string
          option_id: string
        }
        Update: {
          character_class_id?: string
          character_id?: string
          class_id?: string
          created_at?: string
          detail?: string | null
          feature_id?: string
          id?: string
          option_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_feature_choices_character_class_id_character_id__fkey"
            columns: ["character_class_id", "character_id", "class_id"]
            isOneToOne: false
            referencedRelation: "character_classes"
            referencedColumns: ["id", "character_id", "class_id"]
          },
          {
            foreignKeyName: "character_feature_choices_feature_id_class_id_fkey"
            columns: ["feature_id", "class_id"]
            isOneToOne: false
            referencedRelation: "class_features"
            referencedColumns: ["id", "class_id"]
          },
          {
            foreignKeyName: "character_feature_choices_feature_id_option_id_fkey"
            columns: ["feature_id", "option_id"]
            isOneToOne: false
            referencedRelation: "class_feature_options"
            referencedColumns: ["feature_id", "option_id"]
          },
        ]
      }
      character_inventory: {
        Row: {
          added_by: string | null
          character_id: string
          created_at: string
          equipped: boolean
          id: string
          item_id: string
          quantity: number
        }
        Insert: {
          added_by?: string | null
          character_id: string
          created_at?: string
          equipped?: boolean
          id?: string
          item_id: string
          quantity?: number
        }
        Update: {
          added_by?: string | null
          character_id?: string
          created_at?: string
          equipped?: boolean
          id?: string
          item_id?: string
          quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_inventory_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_inventory_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_inventory_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      character_item_descriptions: {
        Row: {
          character_id: string
          custom_description: string | null
          custom_name: string | null
          item_id: string
          updated_at: string
        }
        Insert: {
          character_id: string
          custom_description?: string | null
          custom_name?: string | null
          item_id: string
          updated_at?: string
        }
        Update: {
          character_id?: string
          custom_description?: string | null
          custom_name?: string | null
          item_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_item_descriptions_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_item_descriptions_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      character_proficiencies: {
        Row: {
          character_id: string
          key: string
          kind: string
          level: number
        }
        Insert: {
          character_id: string
          key: string
          kind: string
          level?: number
        }
        Update: {
          character_id?: string
          key?: string
          kind?: string
          level?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_proficiencies_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
        ]
      }
      character_spell_descriptions: {
        Row: {
          character_id: string
          custom_description: string | null
          custom_name: string | null
          spell_id: string
          updated_at: string
        }
        Insert: {
          character_id: string
          custom_description?: string | null
          custom_name?: string | null
          spell_id: string
          updated_at?: string
        }
        Update: {
          character_id?: string
          custom_description?: string | null
          custom_name?: string | null
          spell_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_spell_descriptions_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_spell_descriptions_spell_id_fkey"
            columns: ["spell_id"]
            isOneToOne: false
            referencedRelation: "spells"
            referencedColumns: ["id"]
          },
        ]
      }
      character_spells: {
        Row: {
          character_id: string
          created_at: string
          id: string
          spell_id: string
        }
        Insert: {
          character_id: string
          created_at?: string
          id?: string
          spell_id: string
        }
        Update: {
          character_id?: string
          created_at?: string
          id?: string
          spell_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "character_spells_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: false
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_spells_spell_id_fkey"
            columns: ["spell_id"]
            isOneToOne: false
            referencedRelation: "spells"
            referencedColumns: ["id"]
          },
        ]
      }
      character_stats: {
        Row: {
          ac_bonus: number
          character_id: string
          charisma: number
          constitution: number
          dexterity: number
          hp_current: number
          hp_max: number
          hp_temp: number
          intelligence: number
          race_id: string | null
          speed_override: number | null
          strength: number
          updated_at: string
          wisdom: number
        }
        Insert: {
          ac_bonus?: number
          character_id: string
          charisma?: number
          constitution?: number
          dexterity?: number
          hp_current?: number
          hp_max?: number
          hp_temp?: number
          intelligence?: number
          race_id?: string | null
          speed_override?: number | null
          strength?: number
          updated_at?: string
          wisdom?: number
        }
        Update: {
          ac_bonus?: number
          character_id?: string
          charisma?: number
          constitution?: number
          dexterity?: number
          hp_current?: number
          hp_max?: number
          hp_temp?: number
          intelligence?: number
          race_id?: string | null
          speed_override?: number | null
          strength?: number
          updated_at?: string
          wisdom?: number
        }
        Relationships: [
          {
            foreignKeyName: "character_stats_character_id_fkey"
            columns: ["character_id"]
            isOneToOne: true
            referencedRelation: "characters"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "character_stats_race_id_fkey"
            columns: ["race_id"]
            isOneToOne: false
            referencedRelation: "races"
            referencedColumns: ["id"]
          },
        ]
      }
      characters: {
        Row: {
          campaign_id: string
          copper: number
          created_at: string
          electrum: number
          gold: number
          id: string
          name: string
          platinum: number
          silver: number
          user_id: string
        }
        Insert: {
          campaign_id: string
          copper?: number
          created_at?: string
          electrum?: number
          gold?: number
          id?: string
          name: string
          platinum?: number
          silver?: number
          user_id: string
        }
        Update: {
          campaign_id?: string
          copper?: number
          created_at?: string
          electrum?: number
          gold?: number
          id?: string
          name?: string
          platinum?: number
          silver?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "characters_campaign_id_user_id_fkey"
            columns: ["campaign_id", "user_id"]
            isOneToOne: true
            referencedRelation: "campaign_members"
            referencedColumns: ["campaign_id", "user_id"]
          },
        ]
      }
      class_feature_options: {
        Row: {
          feature_id: string
          option_id: string
        }
        Insert: {
          feature_id: string
          option_id: string
        }
        Update: {
          feature_id?: string
          option_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "class_feature_options_feature_id_fkey"
            columns: ["feature_id"]
            isOneToOne: false
            referencedRelation: "class_features"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_feature_options_option_id_fkey"
            columns: ["option_id"]
            isOneToOne: false
            referencedRelation: "feature_options"
            referencedColumns: ["id"]
          },
        ]
      }
      class_feature_picks: {
        Row: {
          feature_id: string
          level: number
          total: number
        }
        Insert: {
          feature_id: string
          level: number
          total: number
        }
        Update: {
          feature_id?: string
          level?: number
          total?: number
        }
        Relationships: [
          {
            foreignKeyName: "class_feature_picks_feature_id_fkey"
            columns: ["feature_id"]
            isOneToOne: false
            referencedRelation: "class_features"
            referencedColumns: ["id"]
          },
        ]
      }
      class_features: {
        Row: {
          campaign_id: string | null
          choice: string | null
          class_id: string
          created_at: string
          description: string
          id: string
          level: number
          name: string
          subclass_id: string | null
        }
        Insert: {
          campaign_id?: string | null
          choice?: string | null
          class_id: string
          created_at?: string
          description: string
          id?: string
          level: number
          name: string
          subclass_id?: string | null
        }
        Update: {
          campaign_id?: string | null
          choice?: string | null
          class_id?: string
          created_at?: string
          description?: string
          id?: string
          level?: number
          name?: string
          subclass_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "class_features_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_features_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_features_subclass_id_class_id_fkey"
            columns: ["subclass_id", "class_id"]
            isOneToOne: false
            referencedRelation: "subclasses"
            referencedColumns: ["id", "class_id"]
          },
        ]
      }
      classes: {
        Row: {
          campaign_id: string | null
          created_at: string
          description: string
          hit_die: number
          id: string
          name: string
          save_proficiencies: string[]
          spell_ability: string | null
          subclass_level: number
          subclass_title: string
          unarmored_ability: string | null
          weapon_training: string
        }
        Insert: {
          campaign_id?: string | null
          created_at?: string
          description?: string
          hit_die: number
          id?: string
          name: string
          save_proficiencies: string[]
          spell_ability?: string | null
          subclass_level?: number
          subclass_title?: string
          unarmored_ability?: string | null
          weapon_training: string
        }
        Update: {
          campaign_id?: string | null
          created_at?: string
          description?: string
          hit_die?: number
          id?: string
          name?: string
          save_proficiencies?: string[]
          spell_ability?: string | null
          subclass_level?: number
          subclass_title?: string
          unarmored_ability?: string | null
          weapon_training?: string
        }
        Relationships: [
          {
            foreignKeyName: "classes_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      dm_invites: {
        Row: {
          code: string
          created_at: string
          id: string
          label: string | null
          used: boolean
          used_at: string | null
          used_by: string | null
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          label?: string | null
          used?: boolean
          used_at?: string | null
          used_by?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          label?: string | null
          used?: boolean
          used_at?: string | null
          used_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "dm_invites_used_by_fkey"
            columns: ["used_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      feats: {
        Row: {
          benefits: string[]
          campaign_id: string | null
          category: string
          created_at: string
          description: string
          id: string
          name: string
          prerequisite: string | null
          repeatable: boolean
          tags: string[]
        }
        Insert: {
          benefits?: string[]
          campaign_id?: string | null
          category: string
          created_at?: string
          description: string
          id?: string
          name: string
          prerequisite?: string | null
          repeatable?: boolean
          tags?: string[]
        }
        Update: {
          benefits?: string[]
          campaign_id?: string | null
          category?: string
          created_at?: string
          description?: string
          id?: string
          name?: string
          prerequisite?: string | null
          repeatable?: boolean
          tags?: string[]
        }
        Relationships: [
          {
            foreignKeyName: "feats_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      feature_options: {
        Row: {
          campaign_id: string | null
          created_at: string
          description: string
          id: string
          key: string | null
          kind: string
          name: string
          prerequisite: string | null
          source: string | null
        }
        Insert: {
          campaign_id?: string | null
          created_at?: string
          description: string
          id?: string
          key?: string | null
          kind: string
          name: string
          prerequisite?: string | null
          source?: string | null
        }
        Update: {
          campaign_id?: string | null
          created_at?: string
          description?: string
          id?: string
          key?: string | null
          kind?: string
          name?: string
          prerequisite?: string | null
          source?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "feature_options_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      items: {
        Row: {
          armor_category: string | null
          base_armor_class: number | null
          campaign_id: string | null
          created_at: string | null
          damage_dice: string | null
          damage_type: string | null
          description: string | null
          id: string
          kind: string
          name: string
          price_cp: number
          properties: string[] | null
          range_long: number | null
          range_normal: number | null
          stealth_disadvantage: boolean | null
          strength_requirement: number | null
          tags: string[]
          versatile_dice: string | null
          weapon_category: string | null
        }
        Insert: {
          armor_category?: string | null
          base_armor_class?: number | null
          campaign_id?: string | null
          created_at?: string | null
          damage_dice?: string | null
          damage_type?: string | null
          description?: string | null
          id?: string
          kind?: string
          name: string
          price_cp: number
          properties?: string[] | null
          range_long?: number | null
          range_normal?: number | null
          stealth_disadvantage?: boolean | null
          strength_requirement?: number | null
          tags?: string[]
          versatile_dice?: string | null
          weapon_category?: string | null
        }
        Update: {
          armor_category?: string | null
          base_armor_class?: number | null
          campaign_id?: string | null
          created_at?: string | null
          damage_dice?: string | null
          damage_type?: string | null
          description?: string | null
          id?: string
          kind?: string
          name?: string
          price_cp?: number
          properties?: string[] | null
          range_long?: number | null
          range_normal?: number | null
          stealth_disadvantage?: boolean | null
          strength_requirement?: number | null
          tags?: string[]
          versatile_dice?: string | null
          weapon_category?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "items_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      location_dm_notes: {
        Row: {
          location_id: string
          notes: string
        }
        Insert: {
          location_id: string
          notes?: string
        }
        Update: {
          location_id?: string
          notes?: string
        }
        Relationships: [
          {
            foreignKeyName: "location_dm_notes_location_id_fkey"
            columns: ["location_id"]
            isOneToOne: true
            referencedRelation: "locations"
            referencedColumns: ["id"]
          },
        ]
      }
      locations: {
        Row: {
          campaign_id: string
          created_at: string
          description: string | null
          id: string
          is_revealed: boolean
          map_key: string
          name: string
          x: number
          y: number
        }
        Insert: {
          campaign_id: string
          created_at?: string
          description?: string | null
          id?: string
          is_revealed?: boolean
          map_key?: string
          name: string
          x: number
          y: number
        }
        Update: {
          campaign_id?: string
          created_at?: string
          description?: string | null
          id?: string
          is_revealed?: boolean
          map_key?: string
          name?: string
          x?: number
          y?: number
        }
        Relationships: [
          {
            foreignKeyName: "locations_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      npc_dm_notes: {
        Row: {
          notes: string
          npc_id: string
        }
        Insert: {
          notes: string
          npc_id: string
        }
        Update: {
          notes?: string
          npc_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "npc_dm_notes_npc_id_fkey"
            columns: ["npc_id"]
            isOneToOne: true
            referencedRelation: "npcs"
            referencedColumns: ["id"]
          },
        ]
      }
      npcs: {
        Row: {
          campaign_id: string
          created_at: string
          description: string | null
          id: string
          is_dead: boolean
          is_revealed: boolean
          location_id: string | null
          name: string
          portrait_key: string | null
        }
        Insert: {
          campaign_id: string
          created_at?: string
          description?: string | null
          id?: string
          is_dead?: boolean
          is_revealed?: boolean
          location_id?: string | null
          name: string
          portrait_key?: string | null
        }
        Update: {
          campaign_id?: string
          created_at?: string
          description?: string | null
          id?: string
          is_dead?: boolean
          is_revealed?: boolean
          location_id?: string | null
          name?: string
          portrait_key?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "npcs_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "npcs_campaign_id_location_id_fkey"
            columns: ["campaign_id", "location_id"]
            isOneToOne: false
            referencedRelation: "locations"
            referencedColumns: ["campaign_id", "id"]
          },
        ]
      }
      party_currency: {
        Row: {
          campaign_id: string
          copper: number
          electrum: number
          gold: number
          platinum: number
          silver: number
        }
        Insert: {
          campaign_id: string
          copper?: number
          electrum?: number
          gold?: number
          platinum?: number
          silver?: number
        }
        Update: {
          campaign_id?: string
          copper?: number
          electrum?: number
          gold?: number
          platinum?: number
          silver?: number
        }
        Relationships: [
          {
            foreignKeyName: "party_currency_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: true
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      party_inventory: {
        Row: {
          added_by: string | null
          campaign_id: string
          created_at: string
          id: string
          item_id: string
          quantity: number
        }
        Insert: {
          added_by?: string | null
          campaign_id: string
          created_at?: string
          id?: string
          item_id: string
          quantity?: number
        }
        Update: {
          added_by?: string | null
          campaign_id?: string
          created_at?: string
          id?: string
          item_id?: string
          quantity?: number
        }
        Relationships: [
          {
            foreignKeyName: "party_inventory_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "party_inventory_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "party_inventory_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      player_invites: {
        Row: {
          campaign_id: string
          code: string
          created_at: string
          id: string
          label: string | null
          used: boolean
          used_at: string | null
          used_by: string | null
        }
        Insert: {
          campaign_id: string
          code: string
          created_at?: string
          id?: string
          label?: string | null
          used?: boolean
          used_at?: string | null
          used_by?: string | null
        }
        Update: {
          campaign_id?: string
          code?: string
          created_at?: string
          id?: string
          label?: string | null
          used?: boolean
          used_at?: string | null
          used_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "player_invites_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "player_invites_used_by_fkey"
            columns: ["used_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string | null
          id: string
          role: string
        }
        Insert: {
          created_at?: string
          display_name?: string | null
          id: string
          role?: string
        }
        Update: {
          created_at?: string
          display_name?: string | null
          id?: string
          role?: string
        }
        Relationships: []
      }
      races: {
        Row: {
          campaign_id: string | null
          created_at: string
          description: string
          id: string
          name: string
          size: string
          speed: number
        }
        Insert: {
          campaign_id?: string | null
          created_at?: string
          description?: string
          id?: string
          name: string
          size?: string
          speed: number
        }
        Update: {
          campaign_id?: string | null
          created_at?: string
          description?: string
          id?: string
          name?: string
          size?: string
          speed?: number
        }
        Relationships: [
          {
            foreignKeyName: "races_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      schema_migrations: {
        Row: {
          applied_at: string
          version: string
        }
        Insert: {
          applied_at?: string
          version: string
        }
        Update: {
          applied_at?: string
          version?: string
        }
        Relationships: []
      }
      session_recaps: {
        Row: {
          body: string
          campaign_id: string
          created_at: string
          id: string
          last_edited_at: string | null
          last_edited_by: string | null
          session_number: number
          title: string | null
        }
        Insert: {
          body?: string
          campaign_id: string
          created_at?: string
          id?: string
          last_edited_at?: string | null
          last_edited_by?: string | null
          session_number: number
          title?: string | null
        }
        Update: {
          body?: string
          campaign_id?: string
          created_at?: string
          id?: string
          last_edited_at?: string | null
          last_edited_by?: string | null
          session_number?: number
          title?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "session_recaps_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_recaps_last_edited_by_fkey"
            columns: ["last_edited_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      spells: {
        Row: {
          campaign_id: string | null
          casting_time: string
          classes: string[]
          concentration: boolean
          created_at: string
          description: string
          duration: string
          higher_levels: string | null
          id: string
          level: number
          material: boolean
          material_component: string | null
          name: string
          range: string
          ritual: boolean
          school: string
          somatic: boolean
          tags: string[]
          verbal: boolean
        }
        Insert: {
          campaign_id?: string | null
          casting_time: string
          classes?: string[]
          concentration?: boolean
          created_at?: string
          description: string
          duration: string
          higher_levels?: string | null
          id?: string
          level: number
          material?: boolean
          material_component?: string | null
          name: string
          range: string
          ritual?: boolean
          school: string
          somatic?: boolean
          tags?: string[]
          verbal?: boolean
        }
        Update: {
          campaign_id?: string | null
          casting_time?: string
          classes?: string[]
          concentration?: boolean
          created_at?: string
          description?: string
          duration?: string
          higher_levels?: string | null
          id?: string
          level?: number
          material?: boolean
          material_component?: string | null
          name?: string
          range?: string
          ritual?: boolean
          school?: string
          somatic?: boolean
          tags?: string[]
          verbal?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "spells_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      subclasses: {
        Row: {
          campaign_id: string | null
          class_id: string
          created_at: string
          description: string
          id: string
          name: string
          source: string | null
          spell_ability: string | null
        }
        Insert: {
          campaign_id?: string | null
          class_id: string
          created_at?: string
          description?: string
          id?: string
          name: string
          source?: string | null
          spell_ability?: string | null
        }
        Update: {
          campaign_id?: string | null
          class_id?: string
          created_at?: string
          description?: string
          id?: string
          name?: string
          source?: string | null
          spell_ability?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "subclasses_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subclasses_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      add_character_inventory_item: {
        Args: { target_character: string; target_item: string }
        Returns: string
      }
      add_party_inventory_item: {
        Args: { target_campaign: string; target_item: string }
        Returns: string
      }
      adjust_character_currency: {
        Args: { delta: number; denomination: string; target_character: string }
        Returns: number
      }
      adjust_character_hp: {
        Args: { delta: number; target_character: string }
        Returns: {
          ac_bonus: number
          character_id: string
          charisma: number
          constitution: number
          dexterity: number
          hp_current: number
          hp_max: number
          hp_temp: number
          intelligence: number
          race_id: string | null
          speed_override: number | null
          strength: number
          updated_at: string
          wisdom: number
        }[]
        SetofOptions: {
          from: "*"
          to: "character_stats"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      adjust_party_currency: {
        Args: { delta: number; denomination: string; target_campaign: string }
        Returns: number
      }
      can_edit_character: {
        Args: { target_character: string }
        Returns: boolean
      }
      claim_dm_invite: { Args: { invite_code: string }; Returns: undefined }
      claim_player_invite: { Args: { invite_code: string }; Returns: boolean }
      create_campaign: { Args: { campaign_name: string }; Returns: string }
      decrement_character_inventory_item: {
        Args: { target_entry: string }
        Returns: undefined
      }
      decrement_party_inventory_item: {
        Args: { target_entry: string }
        Returns: undefined
      }
      generate_dm_invite: { Args: { invite_label?: string }; Returns: string }
      generate_player_invite: {
        Args: { invite_label?: string; target_campaign: string }
        Returns: string
      }
      is_campaign_dm: { Args: { target_campaign: string }; Returns: boolean }
      is_campaign_member: {
        Args: { target_campaign: string }
        Returns: boolean
      }
      is_dm: { Args: never; Returns: boolean }
      move_character_item_to_party: {
        Args: { target_entry: string }
        Returns: undefined
      }
      move_party_item_to_character: {
        Args: { target_character: string; target_entry: string }
        Returns: undefined
      }
      set_display_name: {
        Args: { new_display_name: string }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const
