-- ============================================================================
-- TABLE: barcode_label_batches
-- PURPOSE: Stores sticker label batches and history for product barcodes & QR codes
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.barcode_label_batches (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT,
    product_name TEXT NOT NULL,
    barcode_data TEXT NOT NULL,
    barcode_type TEXT NOT NULL DEFAULT 'barcode', -- 'barcode' or 'qr'
    price NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    quantity INTEGER NOT NULL DEFAULT 24,
    columns_count INTEGER NOT NULL DEFAULT 3,
    shop_name TEXT,
    sync_status INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast user batch lookups
CREATE INDEX IF NOT EXISTS idx_barcode_label_batches_user_id ON public.barcode_label_batches(user_id);
CREATE INDEX IF NOT EXISTS idx_barcode_label_batches_created_at ON public.barcode_label_batches(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.barcode_label_batches ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can select their own batches
CREATE POLICY "Users can view their own barcode label batches"
    ON public.barcode_label_batches
    FOR SELECT
    USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own batches
CREATE POLICY "Users can insert their own barcode label batches"
    ON public.barcode_label_batches
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own batches
CREATE POLICY "Users can update their own barcode label batches"
    ON public.barcode_label_batches
    FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS Policy: Users can delete their own batches
CREATE POLICY "Users can delete their own barcode label batches"
    ON public.barcode_label_batches
    FOR DELETE
    USING (auth.uid() = user_id);
