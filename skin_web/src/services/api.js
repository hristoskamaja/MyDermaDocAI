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

// Endpoints where a 401 means "wrong credentials" / "no session", not
// "expired access token" - never try to refresh on these.
const NO_REFRESH_PATHS = [
    '/jwt-auth/login/',
    '/jwt-auth/register/',
    '/jwt-auth/refresh/',
    '/jwt-auth/reset-password/request/',
    '/jwt-auth/reset-password/confirm/',
];

// One shared in-flight refresh, so several requests that 401 at the same
// time trigger a single /jwt-auth/refresh/ call instead of one each.
let refreshPromise = null;

function clearSessionAndRedirect() {
    localStorage.removeItem('ss_token');
    localStorage.removeItem('ss_refresh');
    localStorage.removeItem('ss_user');
    if (window.location.pathname !== '/login') {
        window.location.assign('/login');
    }
}

// Uses a bare axios call (not the `api` instance) so this request does not
// go through the interceptors below and can never loop.
function refreshAccessToken() {
    if (!refreshPromise) {
        const refresh = localStorage.getItem('ss_refresh');
        if (!refresh) return Promise.reject(new Error('No refresh token'));

        refreshPromise = axios
            .post(`${BASE_URL}/jwt-auth/refresh/`, { refresh })
            .then((res) => {
                const access = res.data.access;
                localStorage.setItem('ss_token', access);
                // Only present when the backend rotates refresh tokens.
                if (res.data.refresh) {
                    localStorage.setItem('ss_refresh', res.data.refresh);
                }
                return access;
            })
            .finally(() => {
                refreshPromise = null;
            });
    }
    return refreshPromise;
}

// On a 401 (expired access token, 60 min): refresh once, retry the original
// request once, and only log the user out if the refresh itself fails.
api.interceptors.response.use(
    (response) => response,
    async (error) => {
        const original = error.config;
        const status = error.response && error.response.status;
        const url = (original && original.url) || '';

        if (
            status !== 401 ||
            !original ||
            original._retry ||
            NO_REFRESH_PATHS.some((p) => url.includes(p)) ||
            !localStorage.getItem('ss_token')
        ) {
            return Promise.reject(error);
        }

        original._retry = true;

        try {
            const access = await refreshAccessToken();
            original.headers.Authorization = `Bearer ${access}`;
            return api(original);
        } catch (refreshError) {
            clearSessionAndRedirect();
            return Promise.reject(error);
        }
    }
);

// ── JWT Auth ──────────────────────────────────────────────────────────────────
export const jwtAPI = {
    register:       (data) => api.post('/jwt-auth/register/', data),
    login:          (data) => api.post('/jwt-auth/login/', data),
    refresh:        (data) => api.post('/jwt-auth/refresh/', data),   // refresh token in body
    logout:         (data) => api.post('/jwt-auth/logout/', data),    // refresh token in body
    me:             ()     => api.get('/jwt-auth/me/'),
    changePassword: (data) => api.post('/jwt-auth/change-password/', data),
    // Two steps: request emails a signed link, confirm uses its uid + token.
    requestPasswordReset: (data) => api.post('/jwt-auth/reset-password/request/', data),
    confirmPasswordReset: (data) => api.post('/jwt-auth/reset-password/confirm/', data),
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

// ── Tracking (patient skin tracker; every endpoint returns own data only) ─────
export const trackingAPI = {
    // Daily logs. `data` is JSON, or FormData when a photo is attached.
    getLogs:     (params)       => api.get('/tracking/logs/', { params }),
    getLog:      (day)          => api.get(`/tracking/logs/${day}/`),
    saveLog:     (day, data)    => api.put(`/tracking/logs/${day}/`, data,
        data instanceof FormData ? { headers: { 'Content-Type': 'multipart/form-data' } } : undefined),
    deleteLog:   (day)          => api.delete(`/tracking/logs/${day}/`),
    // Photos need the Bearer token, so they are fetched as blobs (never <img src=url>).
    getPhoto:    (day)          => api.get(`/tracking/logs/${day}/photo/`, { responseType: 'blob' }),

    getProducts:   ()           => api.get('/tracking/products/'),
    createProduct: (data)       => api.post('/tracking/products/', data),
    updateProduct: (id, data)   => api.patch(`/tracking/products/${id}/`, data),
    deleteProduct: (id)         => api.delete(`/tracking/products/${id}/`),

    getToday:      ()           => api.get('/tracking/today/'),
    getWeek:       ()           => api.get('/tracking/week/'),
    getTimeline:   (params)     => api.get('/tracking/timeline/', { params }),
    getInsights:   ()           => api.get('/tracking/insights/'),
    getCorrelation:(params)     => api.get('/tracking/correlation/', { params }),
    getWeeklyReport: ()         => api.get('/tracking/weekly-report/'),
    ask:           (data)       => api.post('/tracking/ask/', data),
    getSuggestions:()           => api.get('/tracking/ask/suggestions/'),

    getFoodSuggestions: ()      => api.get('/tracking/food-suggestions/'),

    getReminders:    ()         => api.get('/tracking/reminders/'),
    updateReminders: (data)     => api.patch('/tracking/reminders/', data),

    saveScan:      (analysisId, data) => api.post(`/tracking/scans/${analysisId}/save/`, data),
    deleteAll:     ()           => api.delete('/tracking/data/', { params: { confirm: 'true' } }),
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
