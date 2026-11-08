import { useLang } from '../../../context/LanguageContext';

// Shared loading / error placeholder for the Track pages.
export default function LoadState({ loading, error, onRetry }) {
    const { t } = useLang();
    if (loading) return <div className="pt-loading">{t('common.loading')}</div>;
    if (error) {
        return (
            <div className="pt-card tr-empty">
                <p className="tr-muted">{error}</p>
                {onRetry && <button type="button" className="pt-btn pt-btn--ghost" onClick={onRetry}>{t('track.retry')}</button>}
            </div>
        );
    }
    return null;
}
