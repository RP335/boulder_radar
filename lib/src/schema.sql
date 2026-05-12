-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.areas (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  zone_id uuid NOT NULL,
  name text NOT NULL,
  location USER-DEFINED NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT areas_pkey PRIMARY KEY (id),
  CONSTRAINT areas_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES public.zones(id)
);
CREATE TABLE public.boulders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  zone_id uuid,
  uploaded_by uuid,
  location USER-DEFINED NOT NULL,
  grade text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  area_id uuid,
  first_ascent_user_id uuid,
  CONSTRAINT boulders_pkey PRIMARY KEY (id),
  CONSTRAINT boulders_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id),
  CONSTRAINT boulders_first_ascent_user_id_fkey FOREIGN KEY (first_ascent_user_id) REFERENCES public.users(id),
  CONSTRAINT boulders_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id),
  CONSTRAINT boulders_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES public.zones(id)
);
CREATE TABLE public.images (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  boulder_id uuid,
  landmark_id uuid,
  image_path text NOT NULL,
  has_drawings boolean DEFAULT false,
  drawing_data jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT images_pkey PRIMARY KEY (id),
  CONSTRAINT images_boulder_id_fkey FOREIGN KEY (boulder_id) REFERENCES public.boulders(id),
  CONSTRAINT images_landmark_id_fkey FOREIGN KEY (landmark_id) REFERENCES public.landmarks(id)
);
CREATE TABLE public.landmarks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  boulder_id uuid,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT landmarks_pkey PRIMARY KEY (id),
  CONSTRAINT landmarks_boulder_id_fkey FOREIGN KEY (boulder_id) REFERENCES public.boulders(id)
);
CREATE TABLE public.offline_maps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  zone_id uuid,
  downloaded_at timestamp with time zone DEFAULT now(),
  CONSTRAINT offline_maps_pkey PRIMARY KEY (id),
  CONSTRAINT offline_maps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT offline_maps_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES public.zones(id)
);
CREATE TABLE public.spatial_ref_sys (
  srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
  auth_name character varying,
  auth_srid integer,
  srtext character varying,
  proj4text character varying,
  CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.users (
  id uuid NOT NULL,
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  last_location USER-DEFINED,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.zones (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  location USER-DEFINED NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT zones_pkey PRIMARY KEY (id)
);