-- Admin function to get analyses for a specific user
CREATE OR REPLACE FUNCTION admin_get_user_analyses(p_admin_id UUID, p_target_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    SELECT subscription_tier = 'admin' INTO v_is_admin
    FROM public.profiles WHERE id = p_admin_id;

    IF NOT v_is_admin THEN
        RETURN jsonb_build_object('success', false, 'error', 'Keine Berechtigung');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'analyses', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', sa.id,
                    'symbol', sa.symbol,
                    'asset_type', sa.asset_type,
                    'direction', sa.direction,
                    'confidence', sa.confidence,
                    'expected_move_percent', sa.expected_move_percent,
                    'key_triggers', sa.key_triggers,
                    'risk_factors', sa.risk_factors,
                    'recommendation', sa.recommendation,
                    'summary', sa.summary,
                    'analyzed_at', sa.analyzed_at
                ) ORDER BY sa.analyzed_at DESC
            ), '[]'::jsonb)
            FROM public.saved_analyses sa
            WHERE sa.user_id = p_target_user_id
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
