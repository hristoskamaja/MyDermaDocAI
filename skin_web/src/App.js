import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import { LanguageProvider } from './context/LanguageContext';
import AdminLayout from './components/layout/AdminLayout';
import PatientLayout from './components/layout/PatientLayout';
import Login from './pages/Login/Login';
import Register from './pages/Register/Register';
import Dashboard from './pages/Dashboard/Dashboard';
import Conditions from './pages/Conditions/Conditions';
import Dermatologists from './pages/Dermatologists/Dermatologists';
import Users from './pages/Users/Users';
import AnalysisHistory from './pages/AnalysisHistory/AnalysisHistory';
import Statistics from './pages/Statistics/Statistics';
import Settings from './pages/Settings/Settings';
import Profile from './pages/Profile/Profile';
import Home from './pages/Home/Home';
import Scan from './pages/Scan/Scan';
import ScanResult from './pages/Scan/ScanResult';
import History from './pages/History/History';
import FindDermatologist from './pages/FindDermatologist/FindDermatologist';

function PrivateRoute({ children }) {
    const { isAuthenticated } = useAuth();
    return isAuthenticated ? children : <Navigate to="/login" replace />;
}

// Admin-only pages redirect a regular USER to the patient area instead of
// rendering. Admins are never restricted from the patient-facing pages.
function AdminOnly({ children }) {
    const { user } = useAuth();
    return user?.role === 'ADMIN' ? children : <Navigate to="/home" replace />;
}

// Picks the right shell for the logged-in user's role. A USER account never
// mounts AdminLayout (or anything inside it) — it always gets PatientLayout.
function RoleLayout() {
    const { user } = useAuth();
    return user?.role === 'ADMIN' ? <AdminLayout /> : <PatientLayout />;
}

function HomeRedirect() {
    const { user } = useAuth();
    return <Navigate to={user?.role === 'ADMIN' ? '/dashboard' : '/home'} replace />;
}

function AppRoutes() {
    return (
        <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route path="/" element={<PrivateRoute><RoleLayout /></PrivateRoute>}>
                <Route index        element={<HomeRedirect />} />

                {/* Admin-only */}
                <Route path="dashboard"      element={<AdminOnly><Dashboard /></AdminOnly>} />
                <Route path="conditions"     element={<AdminOnly><Conditions /></AdminOnly>} />
                <Route path="dermatologists" element={<AdminOnly><Dermatologists /></AdminOnly>} />
                <Route path="users"          element={<AdminOnly><Users /></AdminOnly>} />
                <Route path="analyses"       element={<AdminOnly><AnalysisHistory /></AdminOnly>} />
                <Route path="statistics"     element={<AdminOnly><Statistics /></AdminOnly>} />
                <Route path="settings"       element={<AdminOnly><Settings /></AdminOnly>} />

                {/* Shared */}
                <Route path="profile"    element={<Profile />} />

                {/* Patient-facing (admins may view these too, just unrestricted) */}
                <Route path="home"           element={<Home />} />
                <Route path="scan"           element={<Scan />} />
                <Route path="scan/:id"       element={<ScanResult />} />
                <Route path="history"        element={<History />} />
                <Route path="find-dermatologist" element={<FindDermatologist />} />
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
    );
}

export default function App() {
    return (
        <ThemeProvider>
            <LanguageProvider>
                <AuthProvider>
                    <BrowserRouter>
                        <AppRoutes />
                    </BrowserRouter>
                </AuthProvider>
            </LanguageProvider>
        </ThemeProvider>
    );
}
