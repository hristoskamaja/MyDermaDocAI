/// Mirrors skin_web/src/context/LanguageContext.jsx: one flat-ish nested
/// map per language, looked up by dot-notation key via [AppStrings.t].
/// Kept intentionally simple (a Map, not Flutter's ARB/intl machinery) so
/// it's easy to keep in sync with the web app's own translation keys.
class AppStrings {
  static const Map<String, dynamic> en = {
    'common': {
      'loading': 'Loading…',
      'retry': 'Retry',
      'somethingWrong': 'Something went wrong. Please try again.',
    },
    'nav': {
      'home': 'Home',
      'scan': 'Scan',
      'history': 'History',
      'profile': 'Profile',
    },
    'severity': {
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
      'uncertain': 'Uncertain',
    },
    'home': {
      'greeting': 'Hello,',
      'subtitle': 'How does your skin look today?',
      'scanCardTitle': 'Scan your skin',
      'scanCardSub': 'Camera or gallery',
      'recentScans': 'Recent scans',
      'recentError': 'Could not load your recent scans.',
      'recentEmpty': 'No scans yet. Take your first scan to see results here.',
      'findDermatologistTitle': 'Find a dermatologist',
      'findDermatologistSub': 'Browse our curated list',
      'tipsTitle': 'Better photos, better estimates',
      'tipLightingTitle': 'Good lighting',
      'tipLightingBody': 'Scan in natural daylight, avoid harsh shadows.',
      'tipFrameTitle': 'Fill the frame',
      'tipFrameBody': 'Get close so the lesion fills most of the photo.',
    },
    'history': {
      'title': 'My Scan History',
      'subtitle': 'View all your previous skin scans',
      'loadError': 'Could not load your scan history.',
      'empty': 'No scans yet. Your scan history will appear here.',
    },
    'profile': {
      'title': 'Profile',
      'subtitle': 'Manage your account and preferences',
      'changePassword': 'Change password',
      'darkTheme': 'Dark theme',
      'language': 'Language',
      'logout': 'Log out',
      'currentPassword': 'Current password',
      'newPassword': 'New password',
      'cancel': 'Cancel',
      'save': 'Save',
      'pwSuccess': 'Password changed successfully.',
      'required': 'Required',
      'atLeast8': 'At least 8 characters',
    },
    'findDermatologist': {
      'title': 'Find a dermatologist',
      'subtitle': 'Browse dermatologists added by your clinic',
      'loadError': 'Could not load the dermatologist directory.',
      'empty': "Your admin hasn't added any dermatologists to this list yet.",
      'call': 'Call',
      'website': 'Website',
      'linkError': 'Could not open that link.',
      'sortedByDistance': 'Sorted by distance from you',
      'sortedByDistanceCity': 'Sorted by distance from',
      'yourCity': 'Your city',
      'anyCity': 'Any city',
      'useGps': 'Use my location',
      'gpsUnavailable': "Couldn't get your location — pick your city instead",
    },
    'scan': {
      'noPhoto': 'No photo yet',
      'captureHint': 'Center the lesion and hold steady',
      'usePhoto': 'Use this photo',
      'retake': 'Retake',
      'capture': 'Capture',
      'gallery': 'Gallery',
      'analyzing': 'Analyzing your photo…',
      'cameraError': 'Could not access camera/gallery:',
      'genericError': 'Something went wrong while analyzing your photo.',
      'errorTitle': 'We could not analyze that photo',
      'errorDefault': 'Please try again.',
      'chooseDifferent': 'Choose a different photo',
      'scanAgain': 'Scan again',
    },
    'uncertain': {
      'title': "We're not confident about this one",
      'body':
          'The model could not identify this lesion with enough certainty '
          'to give a reliable estimate. Try retaking the photo in better '
          'lighting, or have it reviewed by a professional.',
      'bestGuess': 'Best guess',
      'rescan': 'Rescan',
    },
    'result': {
      'overview': 'Overview',
      'symptoms': 'Symptoms',
      'treatment': 'Treatment',
      'confidenceSuffix': 'confidence',
      'disclaimer':
          'AI-generated estimate — not a medical diagnosis. Always consult '
          'a dermatologist for concerning changes.',
      'seeADoctor': 'SEE A DOCTOR',
      'selfCare': 'SELF-CARE',
      'lifestyle': 'LIFESTYLE',
      'whatToDo': 'What to do',
      'whatToAvoid': 'What to avoid',
      'whenToSeeDoctor': 'When to see a doctor',
      'askAboutResult': 'Ask about this result',
      'askAboutResultSub': 'Get answers to follow-up questions',
      'scanDetailsTitle': 'Scan details',
      'loadError': 'Could not load this scan.',
    },
    'chat': {
      'title': 'ASK ABOUT THIS RESULT',
      'subtitle':
          'Ask a general question about this condition. This is '
          'AI-generated information, not a diagnosis or personal medical advice.',
      'thinking': 'Thinking…',
      'placeholder': 'e.g. What could cause this to change?',
    },
    'auth': {
      'loginTitle': 'Welcome back',
      'loginSubtitle': 'Sign in to continue tracking your skin health.',
      'email': 'Email',
      'emailRequired': 'Email is required',
      'emailInvalid': 'Enter a valid email',
      'password': 'Password',
      'passwordRequired': 'Password is required',
      'signIn': 'Sign in',
      'noAccount': "Don't have an account? ",
      'createOne': 'Create one',
      'loginFailed': 'Login failed. Please try again.',
      'registerTitle': 'Create your account',
      'registerSubtitle': 'Start tracking your skin health with AI-powered scans.',
      'fullName': 'Full name',
      'fullNameRequired': 'Full name is required',
      'passwordMinHint': 'At least 8 characters',
      'passwordMin': 'Use at least 8 characters',
      'createAccount': 'Create account',
      'haveAccount': 'Already have an account? ',
      'registerFailed': 'Registration failed. Please try again.',
    },
    'onboarding': {
      'tagline':
          "Scan your skin, get an instant AI estimate, and know when it's "
          'time to see a dermatologist.',
      'getStarted': 'Get Started',
      'disclaimer': 'Not a substitute for professional medical advice.',
    },
  };

  static const Map<String, dynamic> mk = {
    'common': {
      'loading': 'Вчитување…',
      'retry': 'Обиди се повторно',
      'somethingWrong': 'Нешто тргна наопаку. Пробај повторно.',
    },
    'nav': {
      'home': 'Почетна',
      'scan': 'Скенирај',
      'history': 'Историја',
      'profile': 'Профил',
    },
    'severity': {
      'low': 'Ниска',
      'medium': 'Средна',
      'high': 'Висока',
      'uncertain': 'Несигурно',
    },
    'home': {
      'greeting': 'Здраво,',
      'subtitle': 'Како изгледа твојата кожа денес?',
      'scanCardTitle': 'Скенирај ја кожата',
      'scanCardSub': 'Камера или галерија',
      'recentScans': 'Скорешни скенирања',
      'recentError': 'Не можев да ги вчитам скорешните скенирања.',
      'recentEmpty': 'Сеуште нема скенирања. Направи го првото скенирање за да видиш резултати тука.',
      'findDermatologistTitle': 'Најди дерматолог',
      'findDermatologistSub': 'Разгледај ја нашата листа',
      'tipsTitle': 'Подобри фотографии, подобри процени',
      'tipLightingTitle': 'Добра светлина',
      'tipLightingBody': 'Скенирај на дневна светлина, избегнувај силни сенки.',
      'tipFrameTitle': 'Пополни го кадарот',
      'tipFrameBody': 'Приближи се за промената да пополни поголем дел од фотографијата.',
    },
    'history': {
      'title': 'Историја на скенирања',
      'subtitle': 'Погледни ги сите твои претходни скенирања',
      'loadError': 'Не можев да ја вчитам историјата на скенирања.',
      'empty': 'Сеуште нема скенирања. Твојата историја ќе се појави тука.',
    },
    'profile': {
      'title': 'Профил',
      'subtitle': 'Управувај со твojot профил и преференции',
      'changePassword': 'Смени лозинка',
      'darkTheme': 'Темен режим',
      'language': 'Јазик',
      'logout': 'Одјави се',
      'currentPassword': 'Тековна лозинка',
      'newPassword': 'Нова лозинка',
      'cancel': 'Откажи',
      'save': 'Зачувај',
      'pwSuccess': 'Лозинката е успешно променета.',
      'required': 'Задолжително',
      'atLeast8': 'Најмалку 8 карактери',
    },
    'findDermatologist': {
      'title': 'Најди дерматолог',
      'subtitle': 'Разгледај дерматолози додадени од твојата клиника',
      'loadError': 'Не можев да го вчитам директориумот на дерматолози.',
      'empty': 'Твојот админ сеуште нема додадено дерматолози на оваа листа.',
      'call': 'Јави се',
      'website': 'Веб-страна',
      'linkError': 'Не можев да отворам тој линк.',
      'sortedByDistance': 'Сортирано по близина до тебе',
      'sortedByDistanceCity': 'Сортирано по близина до',
      'yourCity': 'Твој град',
      'anyCity': 'Секаде',
      'useGps': 'Користи ја мојата локација',
      'gpsUnavailable': 'Не можев да ја добијам локацијата — избери град наместо тоа',
    },
    'scan': {
      'noPhoto': 'Сеуште нема фотографија',
      'captureHint': 'Центрирај ја промената и држи стабилно',
      'usePhoto': 'Користи ја оваа фотографија',
      'retake': 'Сликај повторно',
      'capture': 'Сликај',
      'gallery': 'Галерија',
      'analyzing': 'Ја анализирам фотографијата…',
      'cameraError': 'Не можев да пристапам до камера/галерија:',
      'genericError': 'Нешто тргна наопаку при анализата на фотографијата.',
      'errorTitle': 'Не можевме да ја анализираме таа фотографија',
      'errorDefault': 'Пробај повторно.',
      'chooseDifferent': 'Избери друга фотографија',
      'scanAgain': 'Скенирај повторно',
    },
    'uncertain': {
      'title': 'Не сме сигурни за ова',
      'body':
          'Моделот не можеше да ја идентификува промената со доволна сигурност '
          'за да даде веродостојна процена. Пробај да ја сликаш повторно со '
          'подобра светлина, или консултирај професионалец.',
      'bestGuess': 'Најдобра претпоставка',
      'rescan': 'Скенирај повторно',
    },
    'result': {
      'overview': 'Преглед',
      'symptoms': 'Симптоми',
      'treatment': 'Третман',
      'confidenceSuffix': 'доверливост',
      'disclaimer':
          'AI-генерирана процена — не е медицинска дијагноза. Секогаш '
          'консултирај дерматолог за загрижувачки промени.',
      'seeADoctor': 'ПОСЕТИ ЛЕКАР',
      'selfCare': 'САМО-НЕГА',
      'lifestyle': 'НАЧИН НА ЖИВОТ',
      'whatToDo': 'Што да направиш',
      'whatToAvoid': 'Што да избегнуваш',
      'whenToSeeDoctor': 'Кога да одиш на лекар',
      'askAboutResult': 'Прашај за овој резултат',
      'askAboutResultSub': 'Добиј одговори на дополнителни прашања',
      'scanDetailsTitle': 'Детали за скенирање',
      'loadError': 'Не можев да го вчитам ова скенирање.',
    },
    'chat': {
      'title': 'ПРАШАЈ ЗА ОВОЈ РЕЗУЛТАТ',
      'subtitle':
          'Постави општо прашање за оваа состојба. Ова е AI-генерирана '
          'информација, не дијагноза или лична медицинска советка.',
      'thinking': 'Размислувам…',
      'placeholder': 'нпр. Што би можело да го предизвика ова да се промени?',
    },
    'auth': {
      'loginTitle': 'Добредојде повторно',
      'loginSubtitle': 'Најави се за да продолжиш со следење на здравјето на кожата.',
      'email': 'Е-пошта',
      'emailRequired': 'Е-поштата е задолжителна',
      'emailInvalid': 'Внеси валидна е-пошта',
      'password': 'Лозинка',
      'passwordRequired': 'Лозинката е задолжителна',
      'signIn': 'Најави се',
      'noAccount': 'Немаш профил? ',
      'createOne': 'Направи еден',
      'loginFailed': 'Најавата не успеа. Пробај повторно.',
      'registerTitle': 'Направи си профил',
      'registerSubtitle': 'Започни да го следиш здравјето на кожата со AI-скенирања.',
      'fullName': 'Име и презиме',
      'fullNameRequired': 'Името е задолжително',
      'passwordMinHint': 'Најмалку 8 карактери',
      'passwordMin': 'Користи најмалку 8 карактери',
      'createAccount': 'Направи профил',
      'haveAccount': 'Веќе имаш профил? ',
      'registerFailed': 'Регистрацијата не успеа. Пробај повторно.',
    },
    'onboarding': {
      'tagline':
          'Скенирај ја кожата, добиј инстант AI-процена, и знај кога е '
          'време да посетиш дерматолог.',
      'getStarted': 'Започни',
      'disclaimer': 'Не е замена за професионален медицински совет.',
    },
  };

  /// Dot-notation lookup (e.g. "home.recentScans"), falling back to
  /// English if the key is missing in [lang], and to the key itself if
  /// it's missing everywhere (same fallback behavior as the web app's
  /// LanguageContext.jsx -> t()).
  static String t(String lang, String key) {
    final table = lang == 'mk' ? mk : en;
    final value = _lookup(table, key) ?? _lookup(en, key);
    return value ?? key;
  }

  static String? _lookup(Map<String, dynamic> table, String key) {
    dynamic value = table;
    for (final part in key.split('.')) {
      if (value is Map<String, dynamic>) {
        value = value[part];
      } else {
        return null;
      }
    }
    return value is String ? value : null;
  }
}
