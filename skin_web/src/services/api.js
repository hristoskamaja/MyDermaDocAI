import axios from 'axios';

const BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000/api';

const api = axios.create({
    baseURL: BASE_URL,
    headers: { 'Content-Type': 'application/json' },
});

// Attaches the JWT token, and the current UI language (see
// LanguageContext.jsx, same localStorage key), to every request - so
// AI-generated/admin-entered text (condition description/symptoms/
// treatment_overview, recommendations) comes back in whichever language
// the user has selected instead of always defaulting to Macedonian.
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('ss_token');
    if (token) config.headers.Authorization = `Bearer ${token}`;

    const lang = localStorage.getItem('skinscan-lang') || 'en';
    config.params = { ...config.params, lang };

    return config;
});

// ── JWT Auth ──────────────────────────────────────────────────────────────────
export const jwtAPI = {
    register:       (data) => api.post('/jwt-auth/register/', data),
    login:          (data) => api.post('/jwt-auth/login/', data),
    refresh:        (data) => api.post('/jwt-auth/refresh/', data),   // refresh token in body
    logout:         (data) => api.post('/jwt-auth/logout/', data),    // refresh token in body
    me:             ()     => api.get('/jwt-auth/me/'),
    changePassword: (data) => api.post('/jwt-auth/change-password/', data),
    resetPassword:  (data) => api.post('/jwt-auth/reset-password/', data),
};

// ── Users (Admin only) ────────────────────────────────────────────────────────
export const usersAPI = {
    getAll:      (params)   => api.get('/users/', { params }),
    getById:     (id)       => api.get(`/users/${id}/`),
    create:      (data)     => api.post('/users/', data),
    update:      (id, data) => api.patch(`/users/${id}/`, data),
    delete:      (id)       => api.delete(`/users/${id}/`),
    getAnalyses: (id)       => api.get(`/users/${id}/analyses/`),
};

// ── Skin Conditions ───────────────────────────────────────────────────────────
export const conditionsAPI = {
    getAll:              (params)      => api.get('/conditions/', { params }),
    getById:             (id)          => api.get(`/conditions/${id}/`),
    create:              (data)        => api.post('/conditions/', data, {
        headers: { 'Content-Type': 'multipart/form-data' },
    }),
    update:              (id, data)    => api.put(`/conditions/${id}/`, data, {
        headers: { 'Content-Type': 'multipart/form-data' },
    }),
    partialUpdate:       (id, data)    => api.patch(`/conditions/${id}/`, data, {
        headers: { 'Content-Type': 'multipart/form-data' },
    }),
    delete:              (id)          => api.delete(`/conditions/${id}/`),
    getRecommendations:  (id)          => api.get(`/conditions/${id}/recommendations/`),
    addRecommendation:   (id, data)    => api.post(`/conditions/${id}/recommendations/add/`, data),
    removeRecommendation:(id, recId)   => api.delete(`/conditions/${id}/recommendations/${recId}/`),
};

// ── Recommendations ───────────────────────────────────────────────────────────
export const recommendationsAPI = {
    getAll:        (params)   => api.get('/recommendations/', { params }),
    getById:       (id)       => api.get(`/recommendations/${id}/`),
    create:        (data)     => api.post('/recommendations/', data),
    update:        (id, data) => api.put(`/recommendations/${id}/`, data),
    partialUpdate: (id, data) => api.patch(`/recommendations/${id}/`, data),
    delete:        (id)       => api.delete(`/recommendations/${id}/`),
};

// ── Dermatologists ────────────────────────────────────────────────────────────
// Manually maintained list (never scraped) - GET is open to all logged-in
// users (mobile/patient-web), mutations (create/update/delete) are admin-only
// on the backend. Plain JSON, no image field, so no multipart here.
export const dermatologistsAPI = {
    getAll:        (params)   => api.get('/dermatologists/', { params }),
    getById:       (id)       => api.get(`/dermatologists/${id}/`),
    create:        (data)     => api.post('/dermatologists/', data),
    update:        (id, data) => api.put(`/dermatologists/${id}/`, data),
    partialUpdate: (id, data) => api.patch(`/dermatologists/${id}/`, data),
    delete:        (id)       => api.delete(`/dermatologists/${id}/`),
};

// ── Analyses ──────────────────────────────────────────────────────────────────
export const analysesAPI = {
    scanSkin:     (data) => api.post('/analyses/scan-skin/', data, {
        headers: { 'Content-Type': 'multipart/form-data' },
    }),
    getAll:       ()     => api.get('/analyses/'),
    getById:      (id)   => api.get(`/analyses/${id}/`),
    getMy:        ()     => api.get('/analyses/my-analyses/'),
    // Chat Q&A for a specific analysis
    getChat:      (id)       => api.get(`/analyses/${id}/chat/`),
    sendChatMessage: (id, data) => api.post(`/analyses/${id}/chat/`, data),
    // PDF summary - responseType 'blob' because this is a binary file, not
    // JSON, and the request still needs the interceptor's Authorization
    // header (it's a protected endpoint), so it can't be a plain <a href>.
    downloadPdf:  (id)   => api.get(`/analyses/${id}/pdf/`, { responseType: 'blob' }),
};

// ── Dashboard ─────────────────────────────────────────────────────────────────
export const dashboardAPI = {
    getOverview:              () => api.get('/dashboard/overview/'),
    getSummary:               () => api.get('/dashboard/summary/'),
    getMonthlyTrend:          () => api.get('/dashboard/monthly-trend/'),
    getConditionDistribution: () => api.get('/dashboard/condition-distribution/'),
    getRecentAnalyses:        () => api.get('/dashboard/recent-analyses/'),
    getTopDetectedConditions: () => api.get('/dashboard/top-detected-conditions/'),
};

// ── Statistics (Admin only) ───────────────────────────────────────────────────
export const statisticsAPI = {
    getOverview:               () => api.get('/statistics/overview/'),
    getAnalysesByMonth:        () => api.get('/statistics/analyses-by-month/'),
    getConditionsByCategory:   () => api.get('/statistics/conditions-by-category/'),
    getUserGrowth:             () => api.get('/statistics/user-growth/'),
    getDetectionAccuracy:      () => api.get('/statistics/detection-accuracy/'),
    getTopDetectedConditions:  () => api.get('/statistics/top-detected-conditions/'),
};

export default api;
