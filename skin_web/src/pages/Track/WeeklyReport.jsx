import { useCallback, useEffect, useRef, useState } from 'react';
import { Share2, Download } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { trackingAPI } from '../../services/api';
import LoadState from './components/LoadState';
import { StartEmpty } from './components/EmptyState';
import { fmt, shortDate } from './trackUtils';

const SIZE = 1080;

function wrapText(ctx, text, x, y, maxWidth, lineHeight, maxLines) {
    const words = String(text).split(/\s+/);
    let line = '';
    let lines = 0;
    for (const word of words) {
        const test = line ? `${line} ${word}` : word;
        if (ctx.measureText(test).width > maxWidth && line) {
            ctx.fillText(line, x, y);
            y += lineHeight;
            line = word;
            lines += 1;
            if (lines >= maxLines) return y;
        } else {
            line = test;
        }
    }
    if (line) { ctx.fillText(line, x, y); y += lineHeight; }
    return y;
}

// Draws the report on a canvas with the same colors the page currently uses
// (read from CSS variables, so dark mode works). No image library needed.
function drawReportImage(report, labels, lang, colorSource) {
    const css = getComputedStyle(colorSource);
    const v = (name, fallback) => css.getPropertyValue(name).trim() || fallback;
    const bg = v('--surface', '#fffdf8');
    const text = v('--text', '#0e2a2f');
    const muted = v('--text-muted', '#5e6f70');
    const accent = v('--primary', '#0b3b42');
    const border = v('--border', '#e8dece');
    const soft = v('--primary-soft', '#dcefe6');

    const canvas = document.createElement('canvas');
    canvas.width = SIZE;
    canvas.height = SIZE;
    const ctx = canvas.getContext('2d');

    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, SIZE, SIZE);
    ctx.strokeStyle = border;
    ctx.lineWidth = 4;
    ctx.strokeRect(2, 2, SIZE - 4, SIZE - 4);

    const pad = 80;
    ctx.textBaseline = 'alphabetic';

    ctx.fillStyle = accent;
    ctx.font = '700 28px system-ui, sans-serif';
    ctx.fillText('DERMASCAN AI', pad, 120);

    ctx.fillStyle = muted;
    ctx.font = '500 28px system-ui, sans-serif';
    ctx.fillText(`${shortDate(report.period.start, lang)} – ${shortDate(report.period.end, lang)}`, pad, 164);

    ctx.fillStyle = text;
    ctx.font = '600 96px Fraunces, Georgia, serif';
    ctx.fillText(report.trend_label || labels.none, pad, 300);

    ctx.fillStyle = muted;
    ctx.font = '500 30px system-ui, sans-serif';
    ctx.fillText(labels.trend, pad, 346);

    const stats = [
        [labels.avgSeverity, report.avg_severity],
        [labels.sleep, report.avg_sleep !== null ? `${report.avg_sleep} h` : null],
        [labels.stress, report.avg_stress !== null ? `${report.avg_stress} / 10` : null],
        [labels.checkins, `${report.check_ins} / ${report.check_ins_of}`],
    ];
    const boxW = (SIZE - pad * 2 - 30) / 2;
    stats.forEach(([label, value], i) => {
        const x = pad + (i % 2) * (boxW + 30);
        const y = 400 + Math.floor(i / 2) * 190;
        ctx.fillStyle = soft;
        ctx.beginPath();
        ctx.roundRect(x, y, boxW, 160, 28);
        ctx.fill();
        ctx.fillStyle = muted;
        ctx.font = '600 26px system-ui, sans-serif';
        ctx.fillText(label, x + 28, y + 52);
        ctx.fillStyle = text;
        ctx.font = '600 56px Fraunces, Georgia, serif';
        ctx.fillText(value === null || value === undefined ? labels.none : String(value), x + 28, y + 122);
    });

    if (report.top_pattern?.text) {
        ctx.fillStyle = accent;
        ctx.font = '700 24px system-ui, sans-serif';
        ctx.fillText(labels.topPattern.toUpperCase(), pad, 820);
        ctx.fillStyle = text;
        ctx.font = '500 32px system-ui, sans-serif';
        wrapText(ctx, report.top_pattern.text, pad, 868, SIZE - pad * 2, 46, 4);
    }

    return canvas;
}

export default function WeeklyReport() {
    const { t, lang } = useLang();
    const cardRef = useRef(null);
    const [report, setReport] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [notice, setNotice] = useState('');

    const load = useCallback(async () => {
        setLoading(true);
        setError('');
        try {
            const res = await trackingAPI.getWeeklyReport();
            setReport(res.data);
        } catch {
            setError(t('track.error'));
        } finally {
            setLoading(false);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [lang]);

    useEffect(() => { load(); }, [load]);

    if (loading || error) return <LoadState loading={loading} error={error} onRetry={load} />;
    if (!report.check_ins && report.avg_severity_last_week === null) return <StartEmpty />;

    const labels = {
        none: t('track.weekly.none'),
        trend: t('track.weekly.trend'),
        avgSeverity: t('track.weekly.avgSeverity'),
        sleep: t('track.weekly.sleep'),
        stress: t('track.weekly.stress'),
        checkins: t('track.weekly.checkins'),
        topPattern: t('track.weekly.topPattern'),
    };

    const saveImage = () => {
        const canvas = drawReportImage(report, labels, lang, cardRef.current);
        canvas.toBlob((blob) => {
            if (!blob) return;
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `skin-report-${report.period.end}.png`;
            link.click();
            URL.revokeObjectURL(url);
        }, 'image/png');
    };

    const share = async () => {
        setNotice('');
        const text = fmt(t('track.weekly.shareText'), { trend: report.trend_label || labels.none, n: report.check_ins });
        try {
            if (navigator.share) {
                await navigator.share({ title: t('track.weekly.title'), text });
            } else if (navigator.clipboard) {
                await navigator.clipboard.writeText(text);
                setNotice(t('track.weekly.copied'));
            } else {
                setNotice(t('track.weekly.shareError'));
            }
        } catch (err) {
            // The user closing the share sheet is not an error.
            if (err?.name !== 'AbortError') setNotice(t('track.weekly.shareError'));
        }
    };

    const stats = [
        { label: labels.avgSeverity, value: report.avg_severity, hint: report.avg_severity_last_week !== null ? fmt(t('track.weekly.lastWeek'), { value: report.avg_severity_last_week }) : t('track.weekly.scale') },
        { label: labels.sleep, value: report.avg_sleep !== null ? `${report.avg_sleep} h` : null },
        { label: labels.stress, value: report.avg_stress !== null ? `${report.avg_stress} / 10` : null },
        { label: labels.checkins, value: `${report.check_ins} / ${report.check_ins_of}` },
    ];

    return (
        <div className="tr-stack tr-narrow">
            <div>
                <h2 className="pt-h2">{t('track.weekly.title')}</h2>
                <p className="tr-muted">{t('track.weekly.subtitle')}</p>
            </div>

            <div className="pt-card tr-report" ref={cardRef}>
                <p className="tr-eyebrow-sm">{shortDate(report.period.start, lang)} – {shortDate(report.period.end, lang)}</p>
                <p className="tr-muted">{labels.trend}</p>
                <h3 className={`tr-report-trend tr-trend--${report.trend || 'none'}`}>{report.trend_label || labels.none}</h3>

                <div className="tr-report-grid">
                    {stats.map((s) => (
                        <div key={s.label} className="tr-report-stat">
                            <span className="tr-muted tr-small">{s.label}</span>
                            <strong>{s.value === null || s.value === undefined ? labels.none : s.value}</strong>
                            {s.hint && <span className="tr-hint">{s.hint}</span>}
                        </div>
                    ))}
                </div>

                {report.top_pattern?.text && (
                    <div className="tr-report-pattern">
                        <span className="tr-eyebrow-sm">{labels.topPattern}</span>
                        <p>{report.top_pattern.text}</p>
                    </div>
                )}
            </div>

            <div className="tr-modal-actions tr-actions-left">
                <button type="button" className="pt-btn" onClick={share}><Share2 size={16} /> {t('track.weekly.share')}</button>
                <button type="button" className="pt-btn pt-btn--ghost" onClick={saveImage}><Download size={16} /> {t('track.weekly.saveImage')}</button>
            </div>
            {notice && <div className="pt-alert pt-alert--success">{notice}</div>}
        </div>
    );
}
