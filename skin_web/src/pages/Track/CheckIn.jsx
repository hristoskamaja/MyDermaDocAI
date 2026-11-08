import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Frown, Annoyed, Meh, Smile, Laugh, ImagePlus, X } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { trackingAPI } from '../../services/api';
import LoadState from './components/LoadState';
import FaceMap from './components/FaceMap';
import useTrackingPhoto from './useTrackingPhoto';
import {
    AREAS, FOOD_TAGS, SLEEP_QUALITIES, CYCLE_PHASES, SEVERITY_KEYS,
    apiErrorText, fmt, longDate, toISODate,
} from './trackUtils';

const FACES = [
    { value: 1, Icon: Frown },
    { value: 2, Icon: Annoyed },
    { value: 3, Icon: Meh },
    { value: 4, Icon: Smile },
    { value: 5, Icon: Laugh },
];

function toggle(list, value) {
    return list.includes(value) ? list.filter((v) => v !== value) : [...list, value];
}

export default function CheckIn() {
    const { t, lang } = useLang();
    const navigate = useNavigate();
    const day = useMemo(() => toISODate(), []);

    const [loading, setLoading] = useState(true);
    const [loadError, setLoadError] = useState('');
    const [products, setProducts] = useState([]);
    const [cycleEnabled, setCycleEnabled] = useState(false);

    const [rating, setRating] = useState(null);
    const [acne, setAcne] = useState(null);
    const [areas, setAreas] = useState([]);
    const [food, setFood] = useState([]);
    const [sleepHours, setSleepHours] = useState(null);
    const [sleepQuality, setSleepQuality] = useState(null);
    const [stress, setStress] = useState(null);
    const [cycle, setCycle] = useState(null);
    const [am, setAm] = useState([]);
    const [pm, setPm] = useState([]);
    const [notes, setNotes] = useState('');

    const [hasSavedPhoto, setHasSavedPhoto] = useState(false);
    const [removePhoto, setRemovePhoto] = useState(false);
    const [newPhoto, setNewPhoto] = useState(null);
    const [newPhotoUrl, setNewPhotoUrl] = useState(null);
    const fileRef = useRef(null);

    const [saving, setSaving] = useState(false);
    const [saveError, setSaveError] = useState('');

    const savedPhoto = useTrackingPhoto(day, hasSavedPhoto && !removePhoto && !newPhoto);

    useEffect(() => {
        let cancelled = false;
        (async () => {
            try {
                const [prodRes, remRes] = await Promise.all([trackingAPI.getProducts(), trackingAPI.getReminders()]);
                if (cancelled) return;
                setProducts(prodRes.data);
                setCycleEnabled(remRes.data.cycle_tracking_enabled);

                try {
                    const { data } = await trackingAPI.getLog(day);
                    if (cancelled) return;
                    setRating(data.skin_rating);
                    setAcne(data.acne_severity);
                    setAreas(data.affected_areas || []);
                    setFood(data.food_tags || []);
                    setSleepHours(data.sleep_hours);
                    setSleepQuality(data.sleep_quality);
                    setStress(data.stress);
                    setCycle(data.cycle_phase);
                    setAm(data.routine_am || []);
                    setPm(data.routine_pm || []);
                    setNotes(data.notes || '');
                    setHasSavedPhoto(!!data.has_photo);
                } catch (err) {
                    // 404 just means "no check-in yet today".
                    if (err.response?.status !== 404) throw err;
                }
            } catch {
                if (!cancelled) setLoadError(t('track.error'));
            } finally {
                if (!cancelled) setLoading(false);
            }
        })();
        return () => { cancelled = true; };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [day]);

    // Local preview of a freshly picked photo; revoked when replaced or on unmount.
    useEffect(() => {
        if (!newPhoto) { setNewPhotoUrl(null); return undefined; }
        const url = URL.createObjectURL(newPhoto);
        setNewPhotoUrl(url);
        return () => URL.revokeObjectURL(url);
    }, [newPhoto]);

    // Products still in use today, split by time of day.
    const active = products.filter((p) => !p.stopped_on || p.stopped_on >= day);
    const amProducts = active.filter((p) => p.time_of_day === 'AM' || p.time_of_day === 'BOTH');
    const pmProducts = active.filter((p) => p.time_of_day === 'PM' || p.time_of_day === 'BOTH');

    const previewUrl = newPhotoUrl || (!removePhoto ? savedPhoto.url : null);
    const canSave = rating !== null && acne !== null && !saving;

    const pickPhoto = (e) => {
        const file = e.target.files?.[0];
        if (file) { setNewPhoto(file); setRemovePhoto(false); }
        e.target.value = '';
    };

    const clearPhoto = () => {
        setNewPhoto(null);
        if (hasSavedPhoto) setRemovePhoto(true);
    };

    const handleSave = async () => {
        if (!canSave) return;
        setSaving(true);
        setSaveError('');

        const fields = {
            skin_rating: rating,
            acne_severity: acne,
            affected_areas: areas,
            food_tags: food,
            sleep_hours: sleepHours,
            sleep_quality: sleepQuality,
            stress,
            cycle_phase: cycleEnabled ? cycle : null,
            routine_am: am,
            routine_pm: pm,
            notes,
        };

        let body;
        if (newPhoto) {
            // Multipart: list fields travel as JSON strings, which the API accepts.
            body = new FormData();
            Object.entries(fields).forEach(([key, value]) => {
                if (Array.isArray(value)) body.append(key, JSON.stringify(value));
                else body.append(key, value === null || value === undefined ? '' : value);
            });
            body.append('photo', newPhoto);
        } else {
            body = { ...fields };
            if (removePhoto) body.remove_photo = true;
        }

        try {
            await trackingAPI.saveLog(day, body);
            navigate('/track');
        } catch (err) {
            setSaveError(apiErrorText(err, t('track.checkin.saveError')));
            setSaving(false);
        }
    };

    if (loading || loadError) return <LoadState loading={loading} error={loadError} />;

    return (
        <div className="tr-stack tr-checkin">
            <div>
                <h2 className="pt-h2">{t('track.checkin.title')}</h2>
                <p className="tr-muted">{fmt(t('track.checkin.forDate'), { date: longDate(day, lang) })} · {t('track.checkin.subtitle')}</p>
            </div>

            {/* 1 - overall skin + acne severity */}
            <section className="pt-card tr-step">
                <h3 className="tr-step-title"><span className="tr-step-num">1</span>{t('track.checkin.skinTitle')}</h3>
                <div className="tr-faces" role="radiogroup" aria-label={t('track.checkin.rating')}>
                    {FACES.map(({ value, Icon }) => (
                        <button
                            key={value}
                            type="button"
                            role="radio"
                            aria-checked={rating === value}
                            className={`tr-face${rating === value ? ' tr-face--on' : ''}`}
                            onClick={() => setRating(value)}
                        >
                            <Icon size={28} strokeWidth={1.6} />
                            <span>{t(`track.checkin.faces.${value}`)}</span>
                        </button>
                    ))}
                </div>
                <p className="tr-label">{t('track.checkin.acneTitle')}</p>
                <div className="tr-seg" role="radiogroup" aria-label={t('track.checkin.acneTitle')}>
                    {SEVERITY_KEYS.map((key, value) => (
                        <button
                            key={key}
                            type="button"
                            role="radio"
                            aria-checked={acne === value}
                            className={`tr-seg-btn${acne === value ? ' tr-seg-btn--on' : ''}`}
                            onClick={() => setAcne(value)}
                        >
                            {t(`track.severity.${key}`)}
                        </button>
                    ))}
                </div>
            </section>

            {/* 2 - face map + photo */}
            <section className="pt-card tr-step">
                <h3 className="tr-step-title"><span className="tr-step-num">2</span>{t('track.checkin.areasTitle')}</h3>
                <p className="tr-muted">{t('track.checkin.areasHint')}</p>
                <FaceMap areas={AREAS} selected={areas} onToggle={(key) => setAreas((prev) => toggle(prev, key))} />

                <p className="tr-label">{t('track.checkin.photoTitle')}</p>
                {previewUrl ? (
                    <div className="tr-photo">
                        <img src={previewUrl} alt="" className="tr-photo-img" />
                        <button type="button" className="pt-btn pt-btn--ghost" onClick={clearPhoto}>
                            <X size={15} /> {t('track.checkin.photoRemove')}
                        </button>
                    </div>
                ) : null}
                <div>
                    <button type="button" className="pt-btn pt-btn--ghost" onClick={() => fileRef.current?.click()}>
                        <ImagePlus size={16} /> {previewUrl ? t('track.checkin.photoChange') : t('track.checkin.photoAdd')}
                    </button>
                    <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={pickPhoto} />
                </div>
                <p className="tr-hint">{t('track.checkin.photoPrivate')}</p>
            </section>

            {/* 3 - food & drink */}
            <section className="pt-card tr-step">
                <h3 className="tr-step-title"><span className="tr-step-num">3</span>{t('track.checkin.foodTitle')}</h3>
                <p className="tr-muted">{t('track.checkin.foodHint')}</p>
                <div className="tr-chips">
                    {FOOD_TAGS.map((key) => (
                        <button
                            key={key}
                            type="button"
                            className={`tr-chip${food.includes(key) ? ' tr-chip--on' : ''}`}
                            aria-pressed={food.includes(key)}
                            onClick={() => setFood((prev) => toggle(prev, key))}
                        >
                            {t(`track.food.${key}`)}
                        </button>
                    ))}
                </div>
            </section>

            {/* 4 - sleep */}
            <section className="pt-card tr-step">
                <h3 className="tr-step-title"><span className="tr-step-num">4</span>{t('track.checkin.sleepTitle')}</h3>
                <div className="tr-slider-row">
                    <label className="tr-label" htmlFor="tr-sleep">{t('track.checkin.sleepHours')}</label>
                    <strong className="tr-slider-value">{sleepHours === null ? '–' : fmt(t('track.hub.hoursShort'), { n: sleepHours })}</strong>
                </div>
                <input
                    id="tr-sleep"
                    className="tr-slider"
                    type="range" min="0" max="12" step="0.5"
                    value={sleepHours ?? 7}
                    onChange={(e) => setSleepHours(Number(e.target.value))}
                />
                <p className="tr-label">{t('track.checkin.sleepQualityLabel')}</p>
                <div className="tr-seg" role="radiogroup" aria-label={t('track.checkin.sleepQualityLabel')}>
                    {SLEEP_QUALITIES.map((key) => (
                        <button
                            key={key}
                            type="button"
                            role="radio"
                            aria-checked={sleepQuality === key}
                            className={`tr-seg-btn${sleepQuality === key ? ' tr-seg-btn--on' : ''}`}
                            onClick={() => setSleepQuality(sleepQuality === key ? null : key)}
                        >
                            {t(`track.sleepQuality.${key}`)}
                        </button>
                    ))}
                </div>
            </section>

            {/* 5 - stress */}
            <section className="pt-card tr-step">
                <h3 className="tr-step-title"><span className="tr-step-num">5</span>{t('track.checkin.stressTitle')}</h3>
                <div className="tr-slider-row">
                    <label className="tr-label" htmlFor="tr-stress">{t('track.hub.stress')}</label>
                    <strong className="tr-slider-value">{stress === null ? '–' : fmt(t('track.hub.stressOf'), { n: stress })}</strong>
                </div>
                <input
                    id="tr-stress"
                    className="tr-slider"
                    type="range" min="1" max="10" step="1"
                    value={stress ?? 5}
                    onChange={(e) => setStress(Number(e.target.value))}
                />
                <div className="tr-slider-ends"><span>{t('track.checkin.stressLow')}</span><span>{t('track.checkin.stressHigh')}</span></div>
            </section>

            {/* 6 - cycle (opt-in) */}
            <section className="pt-card tr-step">
                <h3 className="tr-step-title"><span className="tr-step-num">6</span>{t('track.checkin.cycleTitle')}</h3>
                {cycleEnabled ? (
                    <>
                        <p className="tr-muted">{t('track.checkin.cycleHint')}</p>
                        <div className="tr-chips">
                            {CYCLE_PHASES.map((key) => (
                                <button
                                    key={key}
                                    type="button"
                                    className={`tr-chip${cycle === key ? ' tr-chip--on' : ''}`}
                                    aria-pressed={cycle === key}
                                    onClick={() => setCycle(key)}
                                >
                                    {t(`track.phases.${key}`)}
                                </button>
                            ))}
                            <button
                                type="button"
                                className={`tr-chip tr-chip--skip${cycle === null ? ' tr-chip--on' : ''}`}
                                aria-pressed={cycle === null}
                                onClick={() => setCycle(null)}
                            >
                                {t('track.checkin.cycleSkip')}
                            </button>
                        </div>
                    </>
                ) : (
                    <p className="tr-muted">
                        {t('track.checkin.cycleOff')}{' '}
                        <Link to="/track/reminders" className="pt-link">{t('track.tabs.reminders')}</Link>
                    </p>
                )}
            </section>

            {/* 7 - routine */}
            <section className="pt-card tr-step">
                <h3 className="tr-step-title"><span className="tr-step-num">7</span>{t('track.checkin.routineTitle')}</h3>
                {active.length === 0 ? (
                    <p className="tr-muted">
                        {t('track.checkin.routineEmpty')}{' '}
                        <Link to="/track/routine" className="pt-link">{t('track.checkin.addProducts')}</Link>
                    </p>
                ) : (
                    <div className="tr-routine-cols">
                        {[
                            { label: t('track.checkin.routineMorning'), list: amProducts, value: am, set: setAm },
                            { label: t('track.checkin.routineEvening'), list: pmProducts, value: pm, set: setPm },
                        ].map(({ label, list, value, set }) => (
                            <div key={label}>
                                <p className="tr-label">{label}</p>
                                {list.length === 0 && <p className="tr-hint">{t('track.checkin.routineEmpty')}</p>}
                                {list.map((p) => (
                                    <label key={p.id} className="tr-check">
                                        <input
                                            type="checkbox"
                                            checked={value.includes(p.id)}
                                            onChange={() => set((prev) => toggle(prev, p.id))}
                                        />
                                        <span>{p.name}<small>{t(`track.steps.${p.step_type}`)}</small></span>
                                    </label>
                                ))}
                            </div>
                        ))}
                    </div>
                )}
            </section>

            <section className="pt-card tr-step">
                <h3 className="tr-step-title">{t('track.checkin.notesTitle')}</h3>
                <textarea
                    className="pt-input tr-textarea"
                    rows={3}
                    maxLength={2000}
                    value={notes}
                    placeholder={t('track.checkin.notesPlaceholder')}
                    onChange={(e) => setNotes(e.target.value)}
                />
            </section>

            {saveError && <div className="pt-alert pt-alert--error">{saveError}</div>}

            <div className="tr-savebar">
                <button type="button" className="pt-btn" onClick={handleSave} disabled={!canSave}>
                    {saving ? t('track.checkin.saving') : t('track.checkin.save')}
                </button>
            </div>
        </div>
    );
}
