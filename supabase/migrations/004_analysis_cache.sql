-- =============================================
-- ANALYSIS CACHING SYSTEM
-- Spart Tokens durch Wiederverwendung von Analysen < 1h
-- =============================================

-- Cached Analyses Tabelle (global, nicht user-spezifisch)
CREATE TABLE IF NOT EXISTS public.cached_analyses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    symbol TEXT NOT NULL,
    asset_type TEXT NOT NULL,
    direction TEXT NOT NULL,
    confidence DECIMAL(5, 2) NOT NULL,
    probability_significant_move DECIMAL(5, 2) NOT NULL DEFAULT 0,
    expected_move_percent DECIMAL(8, 4) NOT NULL,
    timeframe_days INTEGER NOT NULL DEFAULT 7,
    key_triggers JSONB DEFAULT '[]',
    historical_patterns JSONB DEFAULT '[]',
    news_correlations JSONB DEFAULT '[]',
    news_patterns JSONB DEFAULT '[]',
    risk_factors JSONB DEFAULT '[]',
    recommendation TEXT NOT NULL,
    summary TEXT NOT NULL,
    analyzed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Unique constraint: nur eine gecachte Analyse pro Symbol
    UNIQUE(symbol)
);

-- Index fuer schnelle Symbol-Suche
CREATE INDEX IF NOT EXISTS idx_cached_analyses_symbol ON public.cached_analyses(symbol);
CREATE INDEX IF NOT EXISTS idx_cached_analyses_analyzed_at ON public.cached_analyses(analyzed_at);

-- RLS deaktiviert - Cache ist global fuer alle User lesbar
ALTER TABLE public.cached_analyses ENABLE ROW LEVEL SECURITY;

-- Alle authentifizierten User koennen den Cache lesen
CREATE POLICY "Authenticated users can read cache" ON public.cached_analyses
    FOR SELECT USING (auth.role() = 'authenticated');

-- Nur authentifizierte User koennen in den Cache schreiben (via RPC)
CREATE POLICY "Authenticated users can insert cache" ON public.cached_analyses
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update cache" ON public.cached_analyses
    FOR UPDATE USING (auth.role() = 'authenticated');

-- =============================================
-- RPC: Gecachte Analyse abrufen (wenn < 1h alt)
-- =============================================
CREATE OR REPLACE FUNCTION public.get_cached_analysis(p_symbol TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cache RECORD;
    v_cache_age INTERVAL;
BEGIN
    -- Suche nach gecachter Analyse fuer dieses Symbol
    SELECT * INTO v_cache
    FROM public.cached_analyses
    WHERE UPPER(symbol) = UPPER(p_symbol);

    -- Keine gecachte Analyse gefunden
    IF NOT FOUND THEN
        RETURN jsonb_build_object('found', false, 'reason', 'no_cache');
    END IF;

    -- Berechne Alter der Analyse
    v_cache_age := NOW() - v_cache.analyzed_at;

    -- Pruefe ob Analyse aelter als 1 Stunde ist
    IF v_cache_age > INTERVAL '1 hour' THEN
        RETURN jsonb_build_object(
            'found', false,
            'reason', 'cache_expired',
            'age_minutes', EXTRACT(EPOCH FROM v_cache_age) / 60
        );
    END IF;

    -- Gecachte Analyse gefunden und noch gueltig
    RETURN jsonb_build_object(
        'found', true,
        'age_minutes', EXTRACT(EPOCH FROM v_cache_age) / 60,
        'data', jsonb_build_object(
            'symbol', v_cache.symbol,
            'asset_type', v_cache.asset_type,
            'direction', v_cache.direction,
            'confidence', v_cache.confidence,
            'probability_significant_move', v_cache.probability_significant_move,
            'expected_move_percent', v_cache.expected_move_percent,
            'timeframe_days', v_cache.timeframe_days,
            'key_triggers', v_cache.key_triggers,
            'historical_patterns', v_cache.historical_patterns,
            'news_correlations', v_cache.news_correlations,
            'news_patterns', v_cache.news_patterns,
            'risk_factors', v_cache.risk_factors,
            'recommendation', v_cache.recommendation,
            'summary', v_cache.summary,
            'analyzed_at', v_cache.analyzed_at
        )
    );
END;
$$;

-- =============================================
-- RPC: Analyse in Cache speichern (UPSERT)
-- =============================================
CREATE OR REPLACE FUNCTION public.save_cached_analysis(
    p_symbol TEXT,
    p_asset_type TEXT,
    p_direction TEXT,
    p_confidence DECIMAL,
    p_probability_significant_move DECIMAL,
    p_expected_move_percent DECIMAL,
    p_timeframe_days INTEGER,
    p_key_triggers JSONB,
    p_historical_patterns JSONB,
    p_news_correlations JSONB,
    p_news_patterns JSONB,
    p_risk_factors JSONB,
    p_recommendation TEXT,
    p_summary TEXT,
    p_analyzed_at TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- UPSERT: Update wenn Symbol existiert, sonst Insert
    INSERT INTO public.cached_analyses (
        symbol,
        asset_type,
        direction,
        confidence,
        probability_significant_move,
        expected_move_percent,
        timeframe_days,
        key_triggers,
        historical_patterns,
        news_correlations,
        news_patterns,
        risk_factors,
        recommendation,
        summary,
        analyzed_at,
        created_at
    ) VALUES (
        UPPER(p_symbol),
        p_asset_type,
        p_direction,
        p_confidence,
        p_probability_significant_move,
        p_expected_move_percent,
        p_timeframe_days,
        p_key_triggers,
        p_historical_patterns,
        p_news_correlations,
        p_news_patterns,
        p_risk_factors,
        p_recommendation,
        p_summary,
        p_analyzed_at,
        NOW()
    )
    ON CONFLICT (symbol) DO UPDATE SET
        asset_type = EXCLUDED.asset_type,
        direction = EXCLUDED.direction,
        confidence = EXCLUDED.confidence,
        probability_significant_move = EXCLUDED.probability_significant_move,
        expected_move_percent = EXCLUDED.expected_move_percent,
        timeframe_days = EXCLUDED.timeframe_days,
        key_triggers = EXCLUDED.key_triggers,
        historical_patterns = EXCLUDED.historical_patterns,
        news_correlations = EXCLUDED.news_correlations,
        news_patterns = EXCLUDED.news_patterns,
        risk_factors = EXCLUDED.risk_factors,
        recommendation = EXCLUDED.recommendation,
        summary = EXCLUDED.summary,
        analyzed_at = EXCLUDED.analyzed_at,
        created_at = NOW();

    RETURN jsonb_build_object('success', true);
END;
$$;

-- =============================================
-- RPC: Cache-Statistiken (fuer Admin)
-- =============================================
CREATE OR REPLACE FUNCTION public.get_cache_statistics()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total INTEGER;
    v_fresh INTEGER;
    v_expired INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total FROM public.cached_analyses;

    SELECT COUNT(*) INTO v_fresh
    FROM public.cached_analyses
    WHERE analyzed_at > NOW() - INTERVAL '1 hour';

    v_expired := v_total - v_fresh;

    RETURN jsonb_build_object(
        'total_cached', v_total,
        'fresh_count', v_fresh,
        'expired_count', v_expired
    );
END;
$$;

-- =============================================
-- Optional: Cleanup alte Cache-Eintraege (> 24h)
-- Kann als Cron-Job eingerichtet werden
-- =============================================
CREATE OR REPLACE FUNCTION public.cleanup_old_cache()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM public.cached_analyses
    WHERE analyzed_at < NOW() - INTERVAL '24 hours';

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;
