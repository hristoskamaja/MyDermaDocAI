import { useCallback, useEffect, useState } from 'react';
import { Plus, Pencil, Trash2, Sun, Moon } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { trackingAPI } from '../../services/api';
import LoadState from './components/LoadState';
import { STEP_TYPES, TIME_OF_DAY, apiErrorText, fmt, toISODate } from './trackUtils';

const EMPTY_FORM = {
    name: '', step_type: 'cleanse', time_of_day: 'BOTH', frequency: '', tags: '', started_on: '', stopped_on: '',
};

function ProductModal({ product, onClose, onSaved }) {
    const { t } = useLang();
    const [form, setForm] = useState(() => (product ? {
        name: product.name,
        step_type: product.step_type,
        time_of_day: product.time_of_day,
        frequency: product.frequency || '',
        tags: (product.tags || []).join(', '),
        started_on: product.started_on || '',
        stopped_on: product.stopped_on || '',
    } : EMPTY_FORM));
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState('');

    const set = (key) => (e) => setForm((prev) => ({ ...prev, [key]: e.target.value }));

    const submit = async (e) => {
        e.preventDefault();
        setSaving(true);
        setError('');
        const payload = {
            name: form.name.trim(),
            step_type: form.step_type,
            time_of_day: form.time_of_day,
            frequency: form.frequency.trim(),
            tags: form.tags.split(',').map((s) => s.trim()).filter(Boolean),
            started_on: form.started_on || null,
            stopped_on: form.stopped_on || null,
        };
        try {
            if (product) await trackingAPI.updateProduct(product.id, payload);
            else await trackingAPI.createProduct(payload);
            onSaved();
        } catch (err) {
            setError(apiErrorText(err, t('track.routine.saveError')));
            setSaving(false);
        }
    };

    return (
        <div className="tr-modal-backdrop" onClick={onClose}>
            <form className="pt-card tr-modal" onClick={(e) => e.stopPropagation()} onSubmit={submit} role="dialog" aria-modal="true">
                <h2 className="pt-h2">{product ? t('track.routine.editProduct') : t('track.routine.addProduct')}</h2>

                <label className="pt-field">
                    <span className="pt-label">{t('track.routine.name')}</span>
                    <input className="pt-input" required maxLength={100} value={form.name}
                        placeholder={t('track.routine.namePlaceholder')} onChange={set('name')} />
                </label>

                <div className="tr-form-grid">
                    <label className="pt-field">
                        <span className="pt-label">{t('track.routine.step')}</span>
                        <select className="pt-input" value={form.step_type} onChange={set('step_type')}>
                            {STEP_TYPES.map((s) => <option key={s} value={s}>{t(`track.steps.${s}`)}</option>)}
                        </select>
                    </label>
                    <label className="pt-field">
                        <span className="pt-label">{t('track.routine.when')}</span>
                        <select className="pt-input" value={form.time_of_day} onChange={set('time_of_day')}>
                            {TIME_OF_DAY.map((s) => <option key={s} value={s}>{t(`track.timeOfDay.${s}`)}</option>)}
                        </select>
                    </label>
                </div>

                <label className="pt-field">
                    <span className="pt-label">{t('track.routine.frequency')}</span>
                    <input className="pt-input" maxLength={40} value={form.frequency}
                        placeholder={t('track.routine.frequencyPh')} onChange={set('frequency')} />
                </label>
                <label className="pt-field">
                    <span className="pt-label">{t('track.routine.tags')}</span>
                    <input className="pt-input" value={form.tags} placeholder={t('track.routine.tagsPh')} onChange={set('tags')} />
                </label>

                <div className="tr-form-grid">
                    <label className="pt-field">
                        <span className="pt-label">{t('track.routine.startedOn')}</span>
                        <input type="date" className="pt-input" max={toISODate()} value={form.started_on} onChange={set('started_on')} />
                    </label>
                    <label className="pt-field">
                        <span className="pt-label">{t('track.routine.stoppedOn')}</span>
                        <input type="date" className="pt-input" min={form.started_on || undefined} value={form.stopped_on} onChange={set('stopped_on')} />
                    </label>
                </div>

                {error && <div className="pt-alert pt-alert--error">{error}</div>}

                <div className="tr-modal-actions">
                    <button type="button" className="pt-btn pt-btn--ghost" onClick={onClose}>{t('common.cancel')}</button>
                    <button type="submit" className="pt-btn" disabled={saving || !form.name.trim()}>{t('common.save')}</button>
                </div>
            </form>
        </div>
    );
}

function ProductCard({ product, onEdit, onDelete, t }) {
    return (
        <div className={`pt-card tr-product${product.stopped_on ? ' tr-product--stopped' : ''}`}>
            <div className="tr-product-main">
                <span className="tr-tag">{t(`track.steps.${product.step_type}`)}</span>
                <strong>{product.name}</strong>
                <span className="tr-muted tr-small">
                    {t(`track.timeOfDay.${product.time_of_day}`)}
                    {product.frequency && ` · ${product.frequency}`}
                    {product.stopped_on && ` · ${t('track.routine.stopped')} ${product.stopped_on}`}
                </span>
                {product.tags?.length > 0 && (
                    <div className="tr-chips">
                        {product.tags.map((tag) => <span key={tag} className="tr-chip-static">{tag}</span>)}
                    </div>
                )}
            </div>
            <div className="tr-product-actions">
                <button type="button" className="tr-icon-btn" onClick={() => onEdit(product)} aria-label={t('common.edit')}>
                    <Pencil size={16} />
                </button>
                <button type="button" className="tr-icon-btn" onClick={() => onDelete(product)} aria-label={t('common.delete')}>
                    <Trash2 size={16} />
                </button>
            </div>
        </div>
    );
}

export default function Routine() {
    const { t, lang } = useLang();
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [editing, setEditing] = useState(undefined); // undefined = closed, null = new, object = edit

    const load = useCallback(async () => {
        setLoading(true);
        setError('');
        try {
            const res = await trackingAPI.getProducts();
            setProducts(res.data);
        } catch {
            setError(t('track.error'));
        } finally {
            setLoading(false);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [lang]);

    useEffect(() => { load(); }, [load]);

    const remove = async (product) => {
        if (!window.confirm(t('track.routine.confirmDelete'))) return;
        try {
            await trackingAPI.deleteProduct(product.id);
            setProducts((prev) => prev.filter((p) => p.id !== product.id));
        } catch {
            setError(t('track.error'));
        }
    };

    if (loading || error) return <LoadState loading={loading} error={error} onRetry={load} />;

    const today = toISODate();
    const active = products.filter((p) => !p.stopped_on || p.stopped_on >= today);
    const stepOrder = (p) => STEP_TYPES.indexOf(p.step_type);
    const forTime = (times) => active.filter((p) => times.includes(p.time_of_day)).sort((a, b) => stepOrder(a) - stepOrder(b));
    const summaries = [
        { key: 'morning', Icon: Sun,  list: forTime(['AM', 'BOTH']) },
        { key: 'evening', Icon: Moon, list: forTime(['PM', 'BOTH']) },
    ];

    return (
        <div className="tr-stack">
            <div className="tr-row-between tr-wrap">
                <div>
                    <h2 className="pt-h2">{t('track.routine.title')}</h2>
                    <p className="tr-muted">{t('track.routine.subtitle')}</p>
                </div>
                <button type="button" className="pt-btn" onClick={() => setEditing(null)}>
                    <Plus size={16} /> {t('track.routine.addProduct')}
                </button>
            </div>

            {products.length === 0 ? (
                <div className="pt-card tr-empty">
                    <h2 className="pt-h2">{t('track.routine.emptyTitle')}</h2>
                    <p className="tr-muted">{t('track.routine.emptyText')}</p>
                </div>
            ) : (
                <>
                    <div className="tr-routine-cols">
                        {summaries.map(({ key, Icon, list }) => (
                            <div key={key} className="pt-card">
                                <div className="tr-row-between">
                                    <h3 className="tr-step-title"><Icon size={18} /> {t(`track.routine.${key}`)}</h3>
                                    <span className="tr-muted tr-small">{fmt(t('track.routine.steps'), { n: list.length })}</span>
                                </div>
                                <ol className="tr-steps">
                                    {list.map((p) => (
                                        <li key={p.id}>
                                            <span className="tr-tag">{t(`track.steps.${p.step_type}`)}</span> {p.name}
                                        </li>
                                    ))}
                                </ol>
                            </div>
                        ))}
                    </div>

                    <div className="tr-product-list">
                        {products.map((p) => (
                            <ProductCard key={p.id} product={p} t={t} onEdit={setEditing} onDelete={remove} />
                        ))}
                    </div>
                </>
            )}

            {editing !== undefined && (
                <ProductModal
                    product={editing}
                    onClose={() => setEditing(undefined)}
                    onSaved={() => { setEditing(undefined); load(); }}
                />
            )}
        </div>
    );
}
