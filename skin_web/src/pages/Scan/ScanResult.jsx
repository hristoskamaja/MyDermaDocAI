import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { ImageIcon, Info, ArrowUp, RefreshCw, History as HistoryIcon, Contact, Download } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { analysesAPI, conditionsAPI } from '../../services/api';
import PageHeroWave from '../../components/decor/PageHeroWave';
import './ScanResult.css';

// ── Severity badge (mirrors the admin Conditions page visual language) ─────
// `light` renders a translucent-white pill for use on the dark hero band,
// instead of the color-coded pill used everywhere else in the app.
function SeverityBadge({ severity, t, light }) {
    if (light) {
        const labels = { LOW: t('conditions.low'), MEDIUM: t('conditions.medium'), HIGH: t('conditions.high') };
        return <span className="sev-pill sev-pill--onDark">{labels[severity] || severity}</span>;
    }
    const cls = { LOW: 'sev-pill--low', MEDIUM: 'sev-pill--medium', HIGH: 'sev-pill--high' };
    const labels = { LOW: t('conditions.low'), MEDIUM: t('conditions.medium'), HIGH: t('conditions.high') };
    return <span className={`sev-pill ${cls[severity] || ''}`}>{labels[severity] || severity}</span>;
}

const REC_GROUPS = [
    { type: 'MEDICAL_CONSULT', labelKey: 'result.seeADoctor',  cls: 'rec-section--medical'  },
    { type: 'SELF_CARE',       labelKey: 'result.selfCare',    cls: 'rec-section--self'     },
    { type: 'LIFESTYLE',       labelKey: 'result.lifestyle',   cls: 'rec-section--lifestyle' },
];

// ── Chat Q&A section ─────────────────────────────────────────────────────────
function AnalysisChat({ analysisId, t }) {
    const [messages, setMessages]         = useState([]);
    const [loadingHistory, setLoadingHistory] = useState(true);
    const [question, setQuestion]         = useState('');
    const [sending, setSending]           = useState(false);
    const [error, setError]               = useState('');
    const bottomRef = useRef(null);

    useEffect(() => {
        let cancelled = false;
        const loadHistory = async () => {
            try {
                const res = await analysesAPI.getChat(analysisId);
                if (!cancelled) setMessages(res.data || []);
            } catch (err) {
                // Best-effort — a fresh analysis with no history yet is not an error.
            } finally {
                if (!cancelled) setLoadingHistory(false);
            }
        };
        loadHistory();
        return () => { cancelled = true; };
    }, [analysisId]);

    useEffect(() => {
        bottomRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }, [messages, sending]);

    const handleSend = async () => {
        const q = question.trim();
        if (!q || sending) return;
        setSending(true);
        setError('');
        setQuestion('');
        try {
            const res = await analysesAPI.sendChatMessage(analysisId, { question: q });
            const { user_message, assistant_message } = res.data;
            setMessages(prev => [...prev, user_message, assistant_message]);
        } catch (err) {
            console.error('Chat error:', err);
            setError(err.response?.data?.detail || err.response?.data?.question || t('chat.errorGeneric'));
        } finally {
            setSending(false);
        }
    };

    const handleKeyDown = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSend();
        }
    };

    return (
        <div className="chat-section">
            <div className="chat-section-title">{t('chat.title')}</div>
            <p className="chat-section-sub">{t('chat.subtitle')}</p>

            <div className="chat-messages">
                {loadingHistory ? (
                    <div className="chat-loading">{t('common.loading')}</div>
                ) : (
                    messages.map(m => (
                        <div
                            key={m.id}
                            className={`chat-bubble-row ${m.role === 'USER' ? 'chat-bubble-row--user' : 'chat-bubble-row--assistant'}`}
                        >
                            <div className={`chat-bubble ${m.role === 'USER' ? 'chat-bubble--user' : 'chat-bubble--assistant'}`}>
                                {m.content}
                            </div>
                        </div>
                    ))
                )}
                {sending && (
                    <div className="chat-thinking">
                        <span className="chat-thinking-dot" />
                        {t('chat.thinking')}
                    </div>
                )}
                <div ref={bottomRef} />
            </div>

            {error && <div className="chat-error">{error}</div>}

            <div className="chat-input-row">
                <textarea
                    className="chat-input"
                    rows={1}
                    placeholder={t('chat.placeholder')}
                    value={question}
                    disabled={sending}
                    onChange={e => setQuestion(e.target.value)}
                    onKeyDown={handleKeyDown}
                />
                <button className="chat-send-btn" onClick={handleSend} disabled={sending || !question.trim()}>
                    <ArrowUp size={17} strokeWidth={2.2} />
                </button>
            </div>
        </div>
    );
}

// ── Main page ────────────────────────────────────────────────────────────────
export default function ScanResult() {
    const { id } = useParams();
    const { t } = useLang();
    const navigate = useNavigate();

    const [analysis, setAnalysis] = useState(null);
    const [recommendations, setRecommendations] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [downloadingPdf, setDownloadingPdf] = useState(false);
    const [pdfError, setPdfError] = useState('');

    useEffect(() => {
        let cancelled = false;
        const load = async () => {
            setLoading(true);
            setError('');
            try {
                const res = await analysesAPI.getById(id);
                if (cancelled) return;
                setAnalysis(res.data);

                const conditionId = res.data?.condition?.id;
                if (conditionId) {
                    try {
                        const recRes = await conditionsAPI.getRecommendations(conditionId);
                        if (!cancelled) setRecommendations(recRes.data || []);
                    } catch (err) {
                        // Non-fatal: show the result even if recommendations fail to load.
                    }
                }
            } catch (err) {
                if (!cancelled) {
                    setError(err.response?.data?.detail || 'Could not load this analysis.');
                }
            } finally {
                if (!cancelled) setLoading(false);
            }
        };
        load();
        return () => { cancelled = true; };
    }, [id]);

    // Downloaded as a blob (not a plain <a href>) because /analyses/:id/pdf/
    // is a protected endpoint - the request needs the same Authorization
    // header api.js's interceptor attaches to every other call. A temporary
    // <a> + object URL triggers the browser's normal "Save As" behavior
    // once the blob has actually arrived.
    const handleDownloadPdf = async () => {
        if (downloadingPdf) return;
        setDownloadingPdf(true);
        setPdfError('');
        try {
            const res = await analysesAPI.downloadPdf(id);
            const blobUrl = window.URL.createObjectURL(new Blob([res.data], { type: 'application/pdf' }));
            const link = document.createElement('a');
            link.href = blobUrl;
            link.download = `${analysis?.analysis_key || 'scan-result'}.pdf`;
            document.body.appendChild(link);
            link.click();
            link.remove();
            window.URL.revokeObjectURL(blobUrl);
        } catch (err) {
            console.error('PDF download error:', err);
            setPdfError(t('result.downloadPdfError'));
        } finally {
            setDownloadingPdf(false);
        }
    };

    if (loading) return <div className="scan-result-loading">{t('common.loading')}</div>;

    if (error || !analysis) {
        return (
            <div className="scan-result-error">
                <p>{error || 'Analysis not found.'}</p>
                <Link to="/scan" className="btn btn--primary">{t('result.scanAgain')}</Link>
            </div>
        );
    }

    const { condition } = analysis;
    const pct = Math.round((analysis.confidence || 0) * 100);
    const scanDate = analysis.created_at ? analysis.created_at.slice(0, 10) : null;
    const groupedRecs = REC_GROUPS.map(g => ({
        ...g,
        items: recommendations.filter(r => r.type === g.type),
    })).filter(g => g.items.length > 0);

    return (
        <div className="scan-result-page">
            <div className="page-hero-band">
                <PageHeroWave />
            </div>

            <div className="result-title-block">
                <div className="result-title-row">
                    <SeverityBadge severity={condition?.severity} t={t} />
                    {scanDate && <span className="result-date">{scanDate}</span>}
                </div>
                <h1 className="result-title">{condition?.name}</h1>
            </div>

            <div className="result-card">
                <div className="result-image-wrap">
                    {analysis.image
                        ? <img src={analysis.image} alt={condition?.name} className="result-image" />
                        : <div className="result-image-placeholder"><ImageIcon size={30} strokeWidth={1.5} /></div>}
                </div>

                <div className="result-confidence">
                    <div className="result-confidence-row">
                        <span>{t('result.confidence')}</span>
                        <strong>{pct}%</strong>
                    </div>
                    <div className="result-confidence-bar">
                        <div className="result-confidence-fill" style={{ width: `${pct}%` }} />
                    </div>
                </div>

                {analysis.is_low_confidence && (
                    <div className="result-low-conf-banner">{t('result.lowConfidenceWarn')}</div>
                )}

                {condition?.description && (
                    <div className="result-section">
                        <div className="result-section-title">{t('result.description')}</div>
                        <p className="result-section-text">{condition.description}</p>
                    </div>
                )}

                {condition?.symptoms && (
                    <div className="result-section">
                        <div className="result-section-title">{t('result.symptoms')}</div>
                        <p className="result-section-text">{condition.symptoms}</p>
                    </div>
                )}

                {condition?.treatment_overview && (
                    <div className="result-section">
                        <div className="result-section-title">{t('result.treatmentOverview')}</div>
                        <p className="result-section-text">{condition.treatment_overview}</p>
                    </div>
                )}
            </div>

            {groupedRecs.length > 0 && (
                <div className="result-card result-recs">
                    {groupedRecs.map(g => (
                        <div key={g.type} className={`rec-section ${g.cls}`}>
                            <div className="rec-section-title">{t(g.labelKey)}</div>
                            {g.items.map(r => (
                                <div key={r.id} className="rec-card">
                                    <div className="rec-card-name">{r.name}</div>
                                    {r.description && <div className="rec-card-desc">{r.description}</div>}
                                </div>
                            ))}
                            {g.type === 'MEDICAL_CONSULT' && (
                                <Link to="/find-dermatologist" className="rec-derm-link">
                                    <Contact size={14} strokeWidth={1.8} />
                                    {t('result.findDermatologistLink')}
                                </Link>
                            )}
                        </div>
                    ))}
                </div>
            )}

            <div className="result-disclaimer">
                <Info size={18} strokeWidth={1.8} />
                <span>{t('disclaimer.resultText')}</span>
            </div>

            <div className="result-actions">
                <button className="btn btn--primary" onClick={() => navigate('/scan')}>
                    <RefreshCw size={15} strokeWidth={1.8} /> {t('result.scanAgain')}
                </button>
                <button className="btn btn--secondary" onClick={handleDownloadPdf} disabled={downloadingPdf}>
                    <Download size={15} strokeWidth={1.8} />
                    {downloadingPdf ? t('result.downloadingPdf') : t('result.downloadPdf')}
                </button>
                <button className="btn btn--secondary" onClick={() => navigate('/history')}>
                    <HistoryIcon size={15} strokeWidth={1.8} /> {t('result.backToHistory')}
                </button>
            </div>
            {pdfError && <div className="result-low-conf-banner">{pdfError}</div>}

            <div className="result-card">
                <AnalysisChat analysisId={analysis.id} t={t} />
            </div>
        </div>
    );
}
