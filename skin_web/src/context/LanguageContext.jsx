import { createContext, useContext, useState } from 'react';

// ─────────────────────────────────────────────────────────────────────────────
// LanguageContext — MK / EN
// Usage:
//   const { lang, setLang, t } = useLang();
//   t('dashboard.title')  → 'Dashboard' or 'Контролна табла'
//
// Wrap your app root with <LanguageProvider>.
// ─────────────────────────────────────────────────────────────────────────────

const TRANSLATIONS = {
    en: {
        // ── Navigation ───────────────────────────────────────────────────────────
        nav: {
            dashboard:       'Dashboard',
            analyses:        'Analysis History',
            conditions:      'Conditions',
            users:           'Users',
            statistics:      'Statistics',
            settings:        'Settings',
            profile:         'Profile',
            logout:          'Log out',
            home:            'Home',
            scan:            'Scan',
            history:         'History',
            dermatologists:  'Dermatologists',
            findDermatologist: 'Find a Dermatologist',
            doctorsTab:      'Doctors',
        },

        // ── Common ────────────────────────────────────────────────────────────────
        common: {
            save:            'Save',
            cancel:          'Cancel',
            delete:          'Delete',
            edit:            'Edit',
            add:             'Add',
            search:          'Search',
            close:           'Close',
            export:          'Export',
            viewAll:         'View All',
            actions:         'Actions',
            loading:         'Loading…',
            noResults:       'No results found',
            confirm:         'Confirm',
            yes:             'Yes',
            no:              'No',
            total:           'Total',
            status:          'Status',
            name:            'Name',
            email:           'Email',
            date:            'Date',
            type:            'Type',
            all:             'All',
            remove:          'Remove',
            create:          'Create',
        },

        // ── Dashboard ─────────────────────────────────────────────────────────────
        dashboard: {
            title:               'Dashboard',
            subtitle:             "Welcome back, Admin. Here's what's happening.",
            totalAnalyses:        'Total Analyses',
            totalUsers:           'Total Users',
            conditionsDetected:   'Conditions Detected',
            accuracyRate:         'Accuracy Rate',
            monthlyTrend:         'Monthly Trend',
            conditionDistribution:'Condition Distribution',
            recentAnalyses:       'Recent Analyses',
            topDetected:          'Top Detected Conditions',
            lowConfidenceRate:    'Low Confidence Rate',
            greetingMorning:      'Good morning',
            greetingAfternoon:    'Good afternoon',
            greetingEvening:      'Good evening',
            heroCaption:          "Here's your platform snapshot for today.",
            accuracyLabel:        'Model Accuracy',
            quickStats:           'Quick Stats',
        },

        // ── Analysis History ──────────────────────────────────────────────────────
        analyses: {
            title:             'Analysis History',
            subtitle:          'View all previous skin condition analyses',
            healthy:           'Healthy',
            allResults:        'All Results',
            allSeverity:       'All Severity',
            lowConfidenceOnly: 'Low Confidence',
            searchPlaceholder: 'Search by ID or condition…',
            results:           'results',
            id:                'ID',
            condition:         'Condition',
            severity:          'Severity',
            confidence:        'Confidence',
            result:            'Result',
            noAnalyses:        'No analyses found',
            noAnalysesSub:     'Try adjusting your search or filter',
            aiConfidence:      'AI Confidence',
            showingFor:        'Showing analyses for',
            clearFilter:       'Clear filter ×',
            lowConfidenceWarn: 'Uncertain result — low model confidence. Consider a follow-up scan or professional review.',
            uncertain:         'Uncertain',
        },

        // ── Conditions ────────────────────────────────────────────────────────────
        conditions: {
            title:             'Conditions',
            subtitle:          'Manage all skin conditions in the system',
            addBtn:            'Add Condition',
            searchPlaceholder: 'Search conditions…',
            allSeverity:       'All Severity',
            allCategories:     'All Categories',
            low:               'Low',
            medium:            'Medium',
            high:              'High',
            severity:          'Severity',
            category:          'Category',
            key:               'Key',
            keyHint:           'Must match the AI model class name. Cannot be changed after creation.',
            symptoms:          'Symptoms',
            treatmentOverview: 'Treatment Overview',
            recommendations:   'Recommendations',
            noConditionsTitle: 'No conditions found',
            noConditionsSub:   'Try adjusting your search or filter',
            deleteTitle:       'Delete Condition',
            deleteDesc:        'Are you sure you want to delete',
            deleteWarn:        'This cannot be undone.',
            addTitle:          'Add Condition',
            editTitle:         'Edit Condition',
            conditionName:     'Condition Name',
            conditionCategory: 'Category',
            optional:          'optional',
            addExisting:       'Add existing recommendation',
            createNew:         'Create new recommendation',
            noRecommendations: 'No recommendations linked yet',
            selectRecommendation: 'Select a recommendation…',
            descriptionEn:     'Description (English)',
            symptomsEn:        'Symptoms (English)',
            treatmentOverviewEn: 'Treatment Overview (English)',
            autoTranslateHint: 'Auto-translated from the Macedonian text above — leave blank to let AI fill it in, or type your own to override it.',
        },

        // ── Recommendations ───────────────────────────────────────────────────────
        recommendations: {
            title:       'Recommendations',
            name:        'Name',
            description: 'Description',
            type:        'Type',
            selfCare:    'Self Care',
            medical:     'Medical Consult',
            lifestyle:   'Lifestyle',
        },

        // ── Dermatologists (admin CRUD) ──────────────────────────────────────────
        dermatologists: {
            title:             'Dermatologists',
            subtitle:          'Manually maintained directory of dermatologists shown to patients',
            addBtn:            'Add Dermatologist',
            searchPlaceholder: 'Search dermatologists…',
            name:              'Name',
            clinicName:        'Clinic Name',
            city:              'City',
            address:           'Address',
            phone:             'Phone',
            website:           'Website',
            notes:             'Notes',
            active:            'Active',
            inactive:          'Inactive',
            isActive:          'Visible to patients',
            noDermatologistsTitle: 'No dermatologists yet',
            noDermatologistsSub:   'Add the dermatologists you know about by hand — this list is never auto-populated.',
            deleteTitle:       'Delete Dermatologist',
            deleteDesc:        'Are you sure you want to delete',
            deleteWarn:        'This cannot be undone.',
            addTitle:          'Add Dermatologist',
            editTitle:         'Edit Dermatologist',
            optional:          'optional',
        },

        // ── Find a Dermatologist (patient-facing, read-only) ─────────────────────
        findDermatologist: {
            title:             'Find a Dermatologist',
            subtitle:          'Dermatologists added by our team. Reach out directly to book an appointment.',
            empty:             "Your admin hasn't added any dermatologists yet.",
            emptySub:          'Check back later — this list is maintained by hand, not generated automatically.',
            call:              'Call',
            website:           'Visit website',
            yourCity:          'Your city:',
            anyCity:           'Any city',
            sortedByDistance:  'Sorted by distance from your city',
        },

        // ── Users ─────────────────────────────────────────────────────────────────
        users: {
            title:             'Users',
            subtitle:          'Manage all registered users',
            addBtn:            'Add User',
            searchPlaceholder: 'Search users…',
            allUsers:          'All Users',
            admins:            'Admins',
            regularUsers:      'Users',
            admin:             'Admin',
            user:              'User',
            joined:            'Joined',
            role:              'Role',
            noUsersTitle:      'No users found',
            noUsersSub:        'Try adjusting your search or filter',
            deleteTitle:       'Delete User',
            deleteDesc:        'Are you sure you want to delete',
            deleteWarn:        'This cannot be undone.',
            viewAnalyses:      'View Analyses',
            analyses:          'Analyses',
            username:          'Username',
        },

        // ── Statistics ────────────────────────────────────────────────────────────
        statistics: {
            title:             'Statistics',
            subtitle:          'Platform analytics and insights',
            last7days:         'Last 7 days',
            last30days:        'Last 30 days',
            last3months:       'Last 3 months',
            last12months:      'Last 12 months',
            analysesOverTime:  'Analyses Over Time',
            conditionDistribution: 'Condition Distribution',
            totalAnalyses:     'Total Analyses',
            avgConfidence:     'Avg. Confidence',
            lowConfidenceRate: 'Low Confidence Rate',
            userGrowth:        'User Growth',
            topDetected:       'Top Detected Conditions',
            detectionAccuracy: 'Detection Accuracy',
        },

        // ── Settings ──────────────────────────────────────────────────────────────
        settings: {
            title:             'General Settings',
            subtitle:          'System-wide preferences for the admin panel',
            language:          'Language',
            languageDesc:      'Choose the display language for the admin panel interface',
            appearance:        'Appearance',
            appearanceDesc:    'Toggle between dark and light theme',
            notifications:     'Notifications',
            notificationsDesc: 'Control how and when you receive alerts',
            security:          'Security',
            securityDesc:      'Account security and session preferences',
            emailNotif:        'Email Notifications',
            emailNotifSub:     'Receive email alerts for new analyses',
            pushNotif:         'Push Notifications',
            pushNotifSub:      'Browser push notifications for critical alerts',
            twoFactor:         'Two-Factor Authentication',
            twoFactorSub:      'Require a verification code on every login',
            sessionLog:        'Session Activity Log',
            sessionLogSub:     'Keep a log of all admin login sessions',
            saveBtn:           'Save All Changes',
            savedBtn:          'Changes Saved!',
            darkMode:          'Dark Mode',
            darkModeSub:       'Switch between dark and light interface',
            lightMode:         'Light Mode',
        },

        // ── Profile ───────────────────────────────────────────────────────────────
        profile: {
            title:             'Admin Profile',
            subtitle:          'Manage your personal information and password',
            fullName:          'Full Name',
            phone:             'Phone',
            bio:               'Bio',
            updateBtn:         'Update Profile',
            savedBtn:          'Saved',
            changePassword:    'Change Password',
            currentPw:         'Current Password',
            newPw:             'New Password',
            confirmPw:         'Confirm Password',
            changePwBtn:       'Change Password',
            pwSuccess:         'Password changed successfully!',
            pwErrorRequired:   'All password fields are required.',
            pwErrorLength:     'New password must be at least 6 characters.',
            pwErrorMatch:      'New passwords do not match.',
        },

        // ── Login ─────────────────────────────────────────────────────────────────
        login: {
            title:             'Admin Login',
            subtitle:          'Sign in to your admin account',
            emailLabel:        'Email address',
            passwordLabel:     'Password',
            forgotPassword:    'Forgot password?',
            signInBtn:         'Sign In',
            signingIn:         'Signing in…',
            errorEmpty:        'Please fill in all fields.',
            feature1:          'AI Skin Condition Detection',
            feature2:          'Real-time Analytics',
            feature3:          'User Management',
            feature4:          'Analysis History',
            heroTitle:         'Intelligent Skin Condition Detection',
            heroSub:           'AI-powered admin panel for managing conditions, users and analysis history.',
            headline:          'Clinical oversight for AI-assisted skin screening',
            headlineSub:       'Manage conditions, review analyses, and monitor model performance across your platform.',
            noAccount:         "Don't have an account?",
            signUpLink:        'Sign up',
        },

        // ── Register ──────────────────────────────────────────────────────────────
        register: {
            title:             'Create your account',
            subtitle:          'Sign up to scan your skin and get AI-powered insights.',
            fullNameLabel:     'Full name',
            usernameLabel:     'Username',
            usernameOptional:  'optional',
            emailLabel:        'Email address',
            passwordLabel:     'Password',
            signUpBtn:         'Sign up',
            signingUp:         'Creating account…',
            errorEmpty:        'Please fill in all required fields.',
            errorPwLength:     'Password must be at least 6 characters.',
            haveAccount:       'Already have an account?',
            signInLink:        'Sign in',
            heroTitle:         'Know your skin better',
            heroSub:           'Snap a photo of a skin concern and get an instant AI-powered assessment with care recommendations.',
        },

        // ── Home ──────────────────────────────────────────────────────────────────
        home: {
            greetingMorning:   'Good morning',
            greetingAfternoon: 'Good afternoon',
            greetingEvening:   'Good evening',
            heroTitle:         'Know your skin better',
            heroSub:           'Snap a photo of a skin concern and get an instant AI-powered assessment with care recommendations.',
            scanCta:           'Scan your skin',
            scanCtaSub:        'Get an instant AI-powered check',
            whyTitle:          'What makes DermaScanAI different',
            feature1Title:     'Instant AI analysis',
            feature1Sub:       'Get an AI-powered assessment in seconds from a single photo.',
            feature2Title:     'Ask follow-up questions',
            feature2Sub:       'Chat with our AI about your result for more clarity.',
            feature3Title:     'Real dermatologists',
            feature3Sub:       'Browse a curated list of dermatologists when you need expert care.',
            activity:          'Your activity',
            recentScans:       'Recent scans',
            scansUnit:         'scans',
            findDermatologist: 'Find a dermatologist',
            findDermatologistSub: 'Browse our list',
            latestResult:      'Latest result',
            tip:               'Tip: sunscreen reduces the risk of new sun-related skin changes, even on cloudy days.',
        },

        // ── Scan ──────────────────────────────────────────────────────────────────
        scan: {
            title:             'Scan your skin',
            subtitle:          'Take or upload a clear photo of the area you want checked.',
            dropText:          'Drag & drop a photo here, or click to upload',
            dropSub:           'PNG, JPG, WEBP up to 10MB',
            changePhoto:       'Choose a different photo',
            analyzeBtn:        'Analyze',
            analyzing:         'Analyzing your photo…',
            analyzingSub:      'This can take a few seconds.',
            errorTitle:        'We could not analyze that photo',
            errorGeneric:      'Something went wrong while analyzing your photo. Please try again.',
            errorPredictionFailed: 'AI prediction failed. Please try again in a moment.',
            errorConditionMissing: 'We detected a result that is not yet in our database. Please try again later.',
            retry:             'Retry',
            chooseDifferent:   'Choose a different photo',
        },

        // ── Scan Result ──────────────────────────────────────────────────────────
        result: {
            scanResult:        'Scan result',
            confidence:        'Confidence',
            description:       'Description',
            symptoms:          'Symptoms',
            treatmentOverview: 'Treatment Overview',
            seeADoctor:        'See a doctor',
            selfCare:          'Self-care',
            lifestyle:         'Lifestyle',
            noRecommendations: 'No specific recommendations available for this condition.',
            scanAgain:         'Scan again',
            lowConfidenceWarn: 'Uncertain result — low model confidence. Consider a follow-up scan or professional review.',
            backToHistory:     'Back to history',
            findDermatologistLink: 'Find a dermatologist',
            downloadPdf:       'Download PDF',
            downloadingPdf:    'Preparing PDF…',
            downloadPdfError:  'Could not generate the PDF. Please try again.',
        },

        // ── History ───────────────────────────────────────────────────────────────
        history: {
            title:             'My Scan History',
            subtitle:          'View all your previous skin scans',
            empty:             'No scans yet',
            emptySub:          'Your scan results will appear here once you analyze a photo.',
            newScanBtn:        'New scan',
            viewResult:        'View result',
        },

        // ── Chat ──────────────────────────────────────────────────────────────────
        chat: {
            title:             'Ask about this result',
            subtitle:          'Ask a general question about this condition. This is AI-generated information, not a diagnosis or personal medical advice.',
            placeholder:       'e.g. What could cause this to change?',
            send:              'Send',
            thinking:          'Thinking…',
            errorGeneric:      'Something went wrong. Please try again.',
        },

        // ── Disclaimer ────────────────────────────────────────────────────────────
        disclaimer: {
            text: 'AI-generated results — not a substitute for professional medical diagnosis.',
            resultText: 'AI-generated estimate — not a medical diagnosis. Always consult a dermatologist for concerning changes.',
        },
    },

    // ══════════════════════════════════════════════════════════════════════════
    mk: {
        // ── Navigation ───────────────────────────────────────────────────────────
        nav: {
            dashboard:       'Контролна табла',
            analyses:        'Историја на анализи',
            conditions:      'Состојби',
            users:           'Корисници',
            statistics:      'Статистики',
            settings:        'Поставки',
            profile:         'Профил',
            logout:          'Одјава',
            home:            'Почетна',
            scan:            'Скенирај',
            history:         'Историја',
            dermatologists:  'Дерматолози',
            findDermatologist: 'Најди дерматолог',
            doctorsTab:      'Доктори',
        },

        // ── Common ────────────────────────────────────────────────────────────────
        common: {
            save:            'Зачувај',
            cancel:          'Откажи',
            delete:          'Избриши',
            edit:            'Уреди',
            add:             'Додај',
            search:          'Пребарај',
            close:           'Затвори',
            export:          'Извоз',
            viewAll:         'Прикажи сè',
            actions:         'Акции',
            loading:         'Вчитување…',
            noResults:       'Нема резултати',
            confirm:         'Потврди',
            yes:             'Да',
            no:              'Не',
            total:           'Вкупно',
            status:          'Статус',
            name:            'Име',
            email:           'Е-пошта',
            date:            'Датум',
            type:            'Тип',
            all:             'Сите',
            remove:          'Отстрани',
            create:          'Креирај',
        },

        // ── Dashboard ─────────────────────────────────────────────────────────────
        dashboard: {
            title:               'Контролна табла',
            subtitle:             'Добредојдовте, Администратор. Еве што се случува.',
            totalAnalyses:        'Вкупно анализи',
            totalUsers:           'Вкупно корисници',
            conditionsDetected:   'Откриени состојби',
            accuracyRate:         'Точност',
            monthlyTrend:         'Месечен тренд',
            conditionDistribution:'Распределба на состојби',
            recentAnalyses:       'Последни анализи',
            topDetected:          'Најчесто откривани состојби',
            lowConfidenceRate:    'Стапка на ниска доверливост',
            greetingMorning:      'Добро утро',
            greetingAfternoon:    'Добар ден',
            greetingEvening:      'Добра вечер',
            heroCaption:          'Еве преглед на платформата за денес.',
            accuracyLabel:        'Точност на моделот',
            quickStats:           'Брзи статистики',
        },

        // ── Analysis History ──────────────────────────────────────────────────────
        analyses: {
            title:             'Историја на анализи',
            subtitle:          'Прегледај ги сите претходни анализи на состојби на кожа',
            healthy:           'Здраво',
            allResults:        'Сите резултати',
            allSeverity:       'Сите тежини',
            lowConfidenceOnly: 'Ниска доверливост',
            searchPlaceholder: 'Пребарај по ID или состојба…',
            results:           'резултати',
            id:                'ID',
            condition:         'Состојба',
            severity:          'Тежина',
            confidence:        'Доверливост',
            result:            'Резултат',
            noAnalyses:        'Нема пронајдени анализи',
            noAnalysesSub:     'Обидете се да ги прилагодите вашите филтри',
            aiConfidence:      'AI доверливост',
            showingFor:        'Прикажување анализи за',
            clearFilter:       'Отстрани филтер ×',
            lowConfidenceWarn: 'Несигурен резултат — ниска доверливост на моделот. Разгледајте повторно скенирање или стручен преглед.',
            uncertain:         'Несигурно',
        },

        // ── Conditions ────────────────────────────────────────────────────────────
        conditions: {
            title:             'Состојби',
            subtitle:          'Управувај со сите состојби на кожа во системот',
            addBtn:            'Додај состојба',
            searchPlaceholder: 'Пребарај состојби…',
            allSeverity:       'Сите тежини',
            allCategories:     'Сите категории',
            low:               'Ниска',
            medium:            'Средна',
            high:              'Висока',
            severity:          'Тежина',
            category:          'Категорија',
            key:               'Клуч',
            keyHint:           'Мора да се совпаѓа со класата на AI моделот. Не може да се менува по креирање.',
            symptoms:          'Симптоми',
            treatmentOverview: 'Преглед на третман',
            recommendations:   'Препораки',
            noConditionsTitle: 'Нема пронајдени состојби',
            noConditionsSub:   'Обидете се да ги прилагодите вашите филтри',
            deleteTitle:       'Избриши состојба',
            deleteDesc:        'Дали сте сигурни дека сакате да ја избришете',
            deleteWarn:        'Ова не може да се поврати.',
            addTitle:          'Додај состојба',
            editTitle:         'Уреди состојба',
            conditionName:     'Име на состојба',
            conditionCategory: 'Категорија',
            optional:          'опционално',
            addExisting:       'Додај постоечка препорака',
            createNew:         'Креирај нова препорака',
            noRecommendations: 'Нема поврзани препораки',
            selectRecommendation: 'Изберете препорака…',
            descriptionEn:     'Опис (англиски)',
            symptomsEn:        'Симптоми (англиски)',
            treatmentOverviewEn: 'Преглед на третман (англиски)',
            autoTranslateHint: 'Автоматски преведено од македонскиот текст погоре — остави празно за AI да го пополни, или впиши свој текст за да го замениш.',
        },

        // ── Recommendations ───────────────────────────────────────────────────────
        recommendations: {
            title:       'Препораки',
            name:        'Име',
            description: 'Опис',
            type:        'Тип',
            selfCare:    'Само-нега',
            medical:     'Медицинска консултација',
            lifestyle:   'Начин на живот',
        },

        // ── Dermatologists (admin CRUD) ──────────────────────────────────────────
        dermatologists: {
            title:             'Дерматолози',
            subtitle:          'Рачно одржуван именик на дерматолози прикажан на пациентите',
            addBtn:            'Додај дерматолог',
            searchPlaceholder: 'Пребарај дерматолози…',
            name:              'Име',
            clinicName:        'Име на клиника',
            city:              'Град',
            address:           'Адреса',
            phone:             'Телефон',
            website:           'Веб-страница',
            notes:             'Белешки',
            active:            'Активен',
            inactive:          'Неактивен',
            isActive:          'Видлив за пациенти',
            noDermatologistsTitle: 'Сè уште нема дерматолози',
            noDermatologistsSub:   'Додајте дерматолози што ги познавате рачно — оваа листа никогаш не се пополнува автоматски.',
            deleteTitle:       'Избриши дерматолог',
            deleteDesc:        'Дали сте сигурни дека сакате да го избришете',
            deleteWarn:        'Ова не може да се поврати.',
            addTitle:          'Додај дерматолог',
            editTitle:         'Уреди дерматолог',
            optional:          'опционално',
        },

        // ── Find a Dermatologist (patient-facing, read-only) ─────────────────────
        findDermatologist: {
            title:             'Најди дерматолог',
            subtitle:          'Дерматолози додадени од нашиот тим. Контактирајте директно за да закажете преглед.',
            empty:             'Вашиот администратор сè уште нема додадено дерматолози.',
            emptySub:          'Проверете повторно подоцна — оваа листа се одржува рачно, не се генерира автоматски.',
            call:              'Јави се',
            website:           'Посети веб-страница',
            yourCity:          'Твојот град:',
            anyCity:           'Секаде',
            sortedByDistance:  'Сортирано по близина до твојот град',
        },

        // ── Users ─────────────────────────────────────────────────────────────────
        users: {
            title:             'Корисници',
            subtitle:          'Управувај со сите регистрирани корисници',
            addBtn:            'Додај корисник',
            searchPlaceholder: 'Пребарај корисници…',
            allUsers:          'Сите корисници',
            admins:            'Администратори',
            regularUsers:      'Корисници',
            admin:             'Администратор',
            user:              'Корисник',
            joined:            'Зачленет',
            role:              'Улога',
            noUsersTitle:      'Нема пронајдени корисници',
            noUsersSub:        'Обидете се да ги прилагодите вашите филтри',
            deleteTitle:       'Избриши корисник',
            deleteDesc:        'Дали сте сигурни дека сакате да го избришете',
            deleteWarn:        'Ова не може да се поврати.',
            viewAnalyses:      'Прикажи анализи',
            analyses:          'Анализи',
            username:          'Корисничко име',
        },

        // ── Statistics ────────────────────────────────────────────────────────────
        statistics: {
            title:             'Статистики',
            subtitle:          'Аналитика и увиди за платформата',
            last7days:         'Последни 7 дена',
            last30days:        'Последни 30 дена',
            last3months:       'Последни 3 месеци',
            last12months:      'Последни 12 месеци',
            analysesOverTime:  'Анализи низ времето',
            conditionDistribution: 'Распределба на состојби',
            totalAnalyses:     'Вкупно анализи',
            avgConfidence:     'Просечна доверливост',
            lowConfidenceRate: 'Стапка на ниска доверливост',
            userGrowth:        'Раст на корисници',
            topDetected:       'Најчесто откривани состојби',
            detectionAccuracy: 'Точност на детекција',
        },

        // ── Settings ──────────────────────────────────────────────────────────────
        settings: {
            title:             'Општи поставки',
            subtitle:          'Системски преференци за административниот панел',
            language:          'Јазик',
            languageDesc:      'Изберете јазик за приказ на административниот панел',
            appearance:        'Изглед',
            appearanceDesc:    'Префрлете помеѓу темна и светла тема',
            notifications:     'Известувања',
            notificationsDesc: 'Контролирајте кога и како добивате известувања',
            security:          'Безбедност',
            securityDesc:      'Безбедност на сметката и сесиски преференци',
            emailNotif:        'Известувања по е-пошта',
            emailNotifSub:     'Примај известувања по е-пошта за нови анализи',
            pushNotif:         'Push известувања',
            pushNotifSub:      'Известувања во прелистувачот за критични предупредувања',
            twoFactor:         'Двофакторска автентикација',
            twoFactorSub:      'Побарај верификациски код на секоја најава',
            sessionLog:        'Дневник на активноста на сесии',
            sessionLogSub:     'Чувај дневник на сите администраторски сесии',
            saveBtn:           'Зачувај ги промените',
            savedBtn:          'Промените се зачувани!',
            darkMode:          'Темен режим',
            darkModeSub:       'Префрлете помеѓу темен и светол интерфејс',
            lightMode:         'Светол режим',
        },

        // ── Profile ───────────────────────────────────────────────────────────────
        profile: {
            title:             'Администраторски профил',
            subtitle:          'Управувај со личните информации и лозинката',
            fullName:          'Целосно име',
            phone:             'Телефон',
            bio:               'Биографија',
            updateBtn:         'Ажурирај профил',
            savedBtn:          'Зачувано',
            changePassword:    'Промени лозинка',
            currentPw:         'Тековна лозинка',
            newPw:             'Нова лозинка',
            confirmPw:         'Потврди лозинка',
            changePwBtn:       'Промени лозинка',
            pwSuccess:         'Лозинката е успешно сменета!',
            pwErrorRequired:   'Сите полиња за лозинка се задолжителни.',
            pwErrorLength:     'Новата лозинка мора да содржи најмалку 6 знаци.',
            pwErrorMatch:      'Новите лозинки не се совпаѓаат.',
        },

        // ── Login ─────────────────────────────────────────────────────────────────
        login: {
            title:             'Администраторска најава',
            subtitle:          'Најавете се на вашата администраторска сметка',
            emailLabel:        'Е-пошта адреса',
            passwordLabel:     'Лозинка',
            forgotPassword:    'Заборавена лозинка?',
            signInBtn:         'Најави се',
            signingIn:         'Најавување…',
            errorEmpty:        'Ве молиме пополнете ги сите полиња.',
            feature1:          'AI Откривање состојби на кожа',
            feature2:          'Аналитика во реално време',
            feature3:          'Управување со корисници',
            feature4:          'Историја на анализи',
            heroTitle:         'Интелигентно откривање состојби на кожа',
            heroSub:           'AI-базиран административен панел за управување со состојби, корисници и историја на анализи.',
            headline:          'Клинички надзор за AI-асистирано скенирање на кожа',
            headlineSub:       'Управувајте со состојби, прегледувајте анализи и следете ги перформансите на моделот низ вашата платформа.',
            noAccount:         'Немате сметка?',
            signUpLink:        'Регистрирај се',
        },

        // ── Register ──────────────────────────────────────────────────────────────
        register: {
            title:             'Креирај сметка',
            subtitle:          'Регистрирај се за да го скенираш твојот проблем на кожата и добиеш AI увиди.',
            fullNameLabel:     'Целосно име',
            usernameLabel:     'Корисничко име',
            usernameOptional:  'опционално',
            emailLabel:        'Е-пошта адреса',
            passwordLabel:     'Лозинка',
            signUpBtn:         'Регистрирај се',
            signingUp:         'Се креира сметка…',
            errorEmpty:        'Ве молиме пополнете ги сите задолжителни полиња.',
            errorPwLength:     'Лозинката мора да содржи најмалку 6 знаци.',
            haveAccount:       'Веќе имате сметка?',
            signInLink:        'Најави се',
            heroTitle:         'Запознај ја твојата кожа подобро',
            heroSub:           'Сликај ја проблематичната зона и добиј моментална AI проценка со препораки за нега.',
        },

        // ── Home ──────────────────────────────────────────────────────────────────
        home: {
            greetingMorning:   'Добро утро',
            greetingAfternoon: 'Добар ден',
            greetingEvening:   'Добра вечер',
            heroTitle:         'Запознај ја твојата кожа подобро',
            heroSub:           'Сликај ја проблематичната зона и добиј моментална AI проценка со препораки за нега.',
            scanCta:           'Скенирај ја кожата',
            scanCtaSub:        'Добиј моментална AI проверка',
            whyTitle:          'Што го издвојува DermaScanAI',
            feature1Title:     'Моментална AI анализа',
            feature1Sub:       'Добиј AI проценка за неколку секунди од само една слика.',
            feature2Title:     'Постави дополнителни прашања',
            feature2Sub:       'Разговарај со нашиот AI за твојот резултат за поголема јасност.',
            feature3Title:     'Вистински дерматолози',
            feature3Sub:       'Прегледај подготвена листа на дерматолози кога ти треба стручна помош.',
            activity:          'Твојата активност',
            recentScans:       'Скорешни скенирања',
            scansUnit:         'скенирања',
            findDermatologist: 'Најди дерматолог',
            findDermatologistSub: 'Прегледај ја листата',
            latestResult:      'Последен резултат',
            tip:               'Совет: кремот за сончање го намалува ризикот од нови промени на кожата предизвикани од сонце, дури и кога е облачно.',
        },

        // ── Scan ──────────────────────────────────────────────────────────────────
        scan: {
            title:             'Скенирај ја твојата кожа',
            subtitle:          'Сликај или прикачи јасна фотографија на делот кој сакаш да го провериш.',
            dropText:          'Повлечи и пушти слика тука, или кликни за прикачување',
            dropSub:           'PNG, JPG, WEBP до 10MB',
            changePhoto:       'Избери друга слика',
            analyzeBtn:        'Анализирај',
            analyzing:         'Ја анализираме твојата слика…',
            analyzingSub:      'Ова може да потрае неколку секунди.',
            errorTitle:        'Не можевме да ја анализираме сликата',
            errorGeneric:      'Нешто тргна наопаку при анализата на сликата. Обиди се повторно.',
            errorPredictionFailed: 'AI предвидувањето не успеа. Обидете се повторно за момент.',
            errorConditionMissing: 'Детектиравме резултат кој сè уште не е во нашата база. Обидете се подоцна.',
            retry:             'Обиди се повторно',
            chooseDifferent:   'Избери друга слика',
        },

        // ── Scan Result ──────────────────────────────────────────────────────────
        result: {
            scanResult:        'Резултат од скенирање',
            confidence:        'Доверливост',
            description:       'Опис',
            symptoms:          'Симптоми',
            treatmentOverview: 'Преглед на третман',
            seeADoctor:        'Посети лекар',
            selfCare:          'Само-нега',
            lifestyle:         'Начин на живот',
            noRecommendations: 'Нема специфични препораки достапни за оваа состојба.',
            scanAgain:         'Скенирај повторно',
            lowConfidenceWarn: 'Несигурен резултат — ниска доверливост на моделот. Разгледајте повторно скенирање или стручен преглед.',
            backToHistory:     'Назад кон историјата',
            findDermatologistLink: 'Најди дерматолог',
            downloadPdf:       'Преземи PDF',
            downloadingPdf:    'Се подготвува PDF…',
            downloadPdfError:  'Не можев да го генерирам PDF-от. Обиди се повторно.',
        },

        // ── History ───────────────────────────────────────────────────────────────
        history: {
            title:             'Моја историја на скенирања',
            subtitle:          'Прегледај ги сите твои претходни скенирања на кожа',
            empty:             'Сè уште нема скенирања',
            emptySub:          'Твоите резултати ќе се појават тука откако ќе анализираш слика.',
            newScanBtn:        'Ново скенирање',
            viewResult:        'Прикажи резултат',
        },

        // ── Chat ──────────────────────────────────────────────────────────────────
        chat: {
            title:             'Прашај за овој резултат',
            subtitle:          'Постави општо прашање за оваа состојба. Ова е AI-генерирана информација, не дијагноза или лична медицинска советница.',
            placeholder:       'на пр. Што може да предизвика ова да се промени?',
            send:              'Испрати',
            thinking:          'Размислува…',
            errorGeneric:      'Нешто тргна наопаку. Обиди се повторно.',
        },

        // ── Disclaimer ────────────────────────────────────────────────────────────
        disclaimer: {
            text: 'Резултати генерирани со AI — не претставуваат замена за професионална медицинска дијагноза.',
            resultText: 'AI-генерирана проценка — не претставува медицинска дијагноза. Секогаш консултирајте се со дерматолог за загрижувачки промени.',
        },
    },
};

// ─────────────────────────────────────────────────────────────────────────────
const LanguageContext = createContext(null);

export function LanguageProvider({ children }) {
    const [lang, setLang] = useState(() => {
        return localStorage.getItem('skinscan-lang') || 'en';
    });

    const changeLang = (newLang) => {
        setLang(newLang);
        localStorage.setItem('skinscan-lang', newLang);
    };

    // t('settings.title') → translated string
    const t = (key) => {
        const parts = key.split('.');
        let val = TRANSLATIONS[lang];
        for (const p of parts) {
            val = val?.[p];
        }
        // fallback to English if key missing
        if (val === undefined) {
            let fb = TRANSLATIONS['en'];
            for (const p of parts) fb = fb?.[p];
            return fb ?? key;
        }
        return val;
    };

    return (
        <LanguageContext.Provider value={{ lang, setLang: changeLang, t }}>
            {children}
        </LanguageContext.Provider>
    );
}

export function useLang() {
    const ctx = useContext(LanguageContext);
    if (!ctx) throw new Error('useLang must be used inside <LanguageProvider>');
    return ctx;
}
