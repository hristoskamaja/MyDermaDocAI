import { useCallback, useEffect, useState } from 'react';
import { Info } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { trackingAPI } from '../../services/api';
import LoadState from './components/LoadState';
import { apiErrorText } from './trackUtils';

function Switch({ checked, onChange, label }) {
    return (
        <button
            type="button" role="switch" aria-checked={checked} aria-label={label}
            className={`tr-switch${checked ? ' tr-switch--on' : ''}`}
            onClick={() => onChange(!checked)}
        >
            <span />
        </button>
    );
}

export default function Reminders() {
    const { t, lang } = useLang();
    const [settings, setSettings] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [message, setMessage] = useState({ type: '', text: '' });
    const [confirmDelete, setConfirmDelete] = useState(false);

    const load = useCallback(async () => {
        setLoading(true);
        setError('');
        try {
            const res = await trackingAPI.getReminders();
            setSettings(res.data);
        } catch {
            setError(t('track.error'));
        } finally {
            setLoading(false);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [lang]);

    useEffect(() => { load(); }, [load]);

    // Saves one change immediately and keeps the server's answer as the truth.
    const update = async (patch) => {
        const previous = settings;
        setSettings({ ...settings, ...patch });
        setMessage({ type: '', text: '' });
        try {
            const res = await trackingAPI.updateReminders(patch);
            setSettings(res.data);
            setMessage({ type: 'success', text: t('track.reminders.saved') });
        } catch (err) {
            setSettings(previous);
            setMessage({ type: 'error', text: apiErrorText(err, t('track.reminders.saveError')) });
        }
    };

    const deleteAll = async () => {
        try {
            await trackingAPI.deleteAll();
            setConfirmDelete(false);
            await load();
            setMessage({ type: 'success', text: t('track.reminders.deleted') });
        } catch (err) {
            setMessage({ type: 'error', text: apiErrorText(err, t('track.error')) });
        }
    };

    if (loading || error) return <LoadState loading={loading} error={error} onRetry={load} />;

    // The API returns the time as HH:MM:SS; the time input wants HH:MM.
    const time = (settings.checkin_time || '20:00').slice(0, 5);

    return (
        <div className="tr-stack pt-narrow">
            <div>
                <h2 className="pt-h2">{t('track.reminders.title')}</h2>
                <p className="tr-muted">{t('track.reminders.subtitle')}</p>
            </div>

            <div className="pt-card tr-settings">
                <div className="tr-setting">
                    <span className="tr-setting-label">{t('track.reminders.checkin')}</span>
                    <Switch checked={settings.checkin_enabled} label={t('track.reminders.checkin')}
                        onChange={(v) => update({ checkin_enabled: v })} />
                </div>
                {settings.checkin_enabled && (
                    <label className="tr-setting">
                        <span className="tr-setting-label">{t('track.reminders.checkinTime')}</span>
                        <input type="time" className="pt-input tr-input-narrow" value={time}
                            onChange={(e) => e.target.value && update({ checkin_time: e.target.value })} />
                    </label>
                )}

                <div className="tr-setting">
                    <span className="tr-setting-label">{t('track.reminders.rescan')}</span>
                    <Switch checked={settings.rescan_enabled} label={t('track.reminders.rescan')}
                        onChange={(v) => update({ rescan_enabled: v })} />
                </div>
                {settings.rescan_enabled && (
                    <label className="tr-setting">
                        <span className="tr-setting-label">{t('track.reminders.rescanWeeks')}</span>
                        <span className="tr-inline">
                            <input type="number" min="1" max="12" className="pt-input tr-input-narrow"
                                value={settings.rescan_weeks}
                                onChange={(e) => {
                                    const n = Number(e.target.value);
                                    if (n >= 1 && n <= 12) update({ rescan_weeks: n });
                                }} />
                            {t('track.reminders.weeks')}
                        </span>
                    </label>
                )}

                <div className="tr-setting">
                    <span className="tr-setting-label">
                        {t('track.reminders.cycle')}
                        <small>{t('track.reminders.cycleHint')}</small>
                    </span>
                    <Switch checked={settings.cycle_tracking_enabled} label={t('track.reminders.cycle')}
                        onChange={(v) => update({ cycle_tracking_enabled: v })} />
                </div>
            </div>

            {message.text && (
                <div className={`pt-alert pt-alert--${message.type === 'error' ? 'error' : 'success'}`}>{message.text}</div>
            )}

            <div className="pt-note">
                <Info size={18} strokeWidth={1.8} />
                <span>{t('track.reminders.note')}</span>
            </div>

            <div className="pt-card tr-danger">
                <h3 className="tr-step-title">{t('track.reminders.dangerTitle')}</h3>
                <p className="tr-muted">{t('track.reminders.dangerText')}</p>
                {confirmDelete ? (
                    <div className="tr-modal-actions">
                        <button type="button" className="pt-btn pt-btn--ghost" onClick={() => setConfirmDelete(false)}>{t('common.cancel')}</button>
                        <button type="button" className="pt-btn tr-btn-danger" onClick={deleteAll}>{t('track.reminders.confirmDelete')}</button>
                    </div>
                ) : (
                    <button type="button" className="pt-btn pt-btn--ghost tr-btn-danger-ghost" onClick={() => setConfirmDelete(true)}>
                        {t('track.reminders.deleteAll')}
                    </button>
                )}
            </div>
        </div>
    );
}
