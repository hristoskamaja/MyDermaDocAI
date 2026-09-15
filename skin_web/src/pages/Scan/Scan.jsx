import { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Camera, ImageIcon, X, AlertTriangle } from 'lucide-react';
import { useLang } from '../../context/LanguageContext';
import { analysesAPI } from '../../services/api';
import PageHeroWave from '../../components/decor/PageHeroWave';
import './Scan.css';

export default function Scan() {
    const { t } = useLang();
    const navigate = useNavigate();
    const fileInputRef = useRef(null);

    const [imageFile,    setImageFile]    = useState(null);
    const [imagePreview, setImagePreview] = useState(null);
    const [dragActive,   setDragActive]   = useState(false);
    const [loading,      setLoading]      = useState(false);
    const [error,        setError]        = useState('');

    const pickFile = (file) => {
        if (!file || !file.type?.startsWith('image/')) return;
        setImageFile(file);
        setImagePreview(URL.createObjectURL(file));
        setError('');
    };

    const handleFileChange = (e) => {
        const file = e.target.files?.[0];
        pickFile(file);
    };

    const handleRemoveImage = () => {
        setImageFile(null);
        setImagePreview(null);
        if (fileInputRef.current) fileInputRef.current.value = '';
    };

    const handleDrop = (e) => {
        e.preventDefault();
        setDragActive(false);
        const file = e.dataTransfer.files?.[0];
        pickFile(file);
    };

    const handleDragOver = (e) => {
        e.preventDefault();
        setDragActive(true);
    };

    const handleDragLeave = (e) => {
        e.preventDefault();
        setDragActive(false);
    };

    const resolveErrorMessage = (err) => {
        const status = err.response?.status;
        if (status === 502) return t('scan.errorPredictionFailed');
        if (status === 404) return t('scan.errorConditionMissing');
        return err.response?.data?.detail || err.response?.data?.image || t('scan.errorGeneric');
    };

    const handleAnalyze = async () => {
        if (!imageFile || loading) return;
        setLoading(true);
        setError('');
        try {
            const formData = new FormData();
            formData.append('image', imageFile);
            const res = await analysesAPI.scanSkin(formData);
            const analysisId = res.data?.analysis?.id;
            if (analysisId) {
                navigate(`/scan/${analysisId}`);
            } else {
                setError(t('scan.errorGeneric'));
            }
        } catch (err) {
            console.error('Scan error:', err);
            setError(resolveErrorMessage(err));
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="scan-page">
            <div className="page-hero-band">
                <PageHeroWave />
                <div className="page-hero-inner">
                    <div className="page-header">
                        <div>
                            <h1 className="page-title">{t('scan.title')}</h1>
                            <p className="page-subtitle">{t('scan.subtitle')}</p>
                        </div>
                    </div>
                </div>
            </div>

            <div className="scan-card">
                {loading ? (
                    <div className="scan-analyzing">
                        <div className="scan-spinner" />
                        <p className="scan-analyzing-text">{t('scan.analyzing')}</p>
                        <p className="scan-analyzing-sub">{t('scan.analyzingSub')}</p>
                    </div>
                ) : imagePreview ? (
                    <div className="scan-preview-wrap">
                        <img src={imagePreview} alt="preview" className="scan-preview" />
                        <button className="scan-remove-btn" onClick={handleRemoveImage}>
                            <X size={13} strokeWidth={2} /> {t('scan.changePhoto')}
                        </button>
                    </div>
                ) : (
                    <div
                        className={`scan-dropzone ${dragActive ? 'scan-dropzone--active' : ''}`}
                        onClick={() => fileInputRef.current?.click()}
                        onDrop={handleDrop}
                        onDragOver={handleDragOver}
                        onDragLeave={handleDragLeave}
                    >
                        <div className="scan-dropzone-icon">
                            <Camera size={26} strokeWidth={1.6} />
                        </div>
                        <span className="scan-dropzone-text">{t('scan.dropText')}</span>
                        <span className="scan-dropzone-sub">{t('scan.dropSub')}</span>
                    </div>
                )}

                <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    className="scan-file-input"
                    onChange={handleFileChange}
                />

                {error && (
                    <div className="scan-error">
                        <AlertTriangle size={15} strokeWidth={1.8} />
                        <span>{error}</span>
                    </div>
                )}

                {!loading && (
                    <button
                        className="btn btn--primary scan-analyze-btn"
                        disabled={!imageFile}
                        onClick={handleAnalyze}
                    >
                        <ImageIcon size={16} strokeWidth={1.8} />
                        {t('scan.analyzeBtn')}
                    </button>
                )}
            </div>
        </div>
    );
}
