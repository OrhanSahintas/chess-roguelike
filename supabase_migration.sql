-- Run this in the Supabase SQL Editor:
-- https://sdiqylrnphkqciukdfno.supabase.co/project/default/sql

-- 1. Create the games table
CREATE TABLE IF NOT EXISTS games (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  white_player_id TEXT,
  black_player_id TEXT,
  board_state JSONB NOT NULL,
  turn TEXT DEFAULT 'white',
  status TEXT DEFAULT 'waiting',
  full_turn_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable realtime for live multiplayer
ALTER PUBLICATION supabase_realtime ADD TABLE games;

-- 3. Enable Row Level Security
ALTER TABLE games ENABLE ROW LEVEL SECURITY;

-- 4. Allow all operations (public game)
CREATE POLICY "Enable all for games" ON games
  FOR ALL USING (true);
