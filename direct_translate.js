const fs = require('fs');
const path = require('path');

// Translation map: English -> { fr, 'es-419', ru, ko }
const translations = {
  // Account
  "First Record": { fr: "Premier enregistrement", "es-419": "Primer registro", ru: "Первая запись", ko: "첫 번째 기록" },
  "Milestone Reached": { fr: "Jalon atteint", "es-419": "Hito alcanzado", ru: "Веха достигнута", ko: "마일스톤 달성" },
  "100 Records": { fr: "100 enregistrements", "es-419": "100 registros", ru: "100 записей", ko: "100개 기록" },
  "Remember 10 People": { fr: "Se souvenir de 10 personnes", "es-419": "Recordar a 10 personas", ru: "Запомнить 10 человек", ko: "10명 기억하기" },
  "30-Day Streak": { fr: "Série de 30 jours", "es-419": "Racha de 30 días", ru: "Серия 30 дней", ko: "30일 연속" },
  "Yearly User": { fr: "Utilisateur annuel", "es-419": "Usuario anual", ru: "Годовой пользователь", ko: "연간 사용자" },
  "Achievements": { fr: "Réalisations", "es-419": "Logros", ru: "Достижения", ko: "업적" },
  "Relationship Reminder Interval": { fr: "Intervalle de rappel de relation", "es-419": "Intervalo de recordatorio de relación", ru: "Интервал напоминания о отношениях", ko: "관계 알림 간격" },
  "Days Recorded": { fr: "Jours enregistrés", "es-419": "Días registrados", ru: "Записанные дни", ko: "기록일" },
  "Decisions": { fr: "Décisions", "es-419": "Decisiones", ru: "Решения", ko: "결정" },
  "People": { fr: "Personnes", "es-419": "Personas", ru: "Люди", ko: "사람" },
  "Total Records": { fr: "Total des enregistrements", "es-419": "Total de registros", ru: "Всего записей", ko: "총 기록" },
  "You have recorded with Sprout for %d days": { fr: "Vous avez enregistré avec Sprout pendant %d jours", "es-419": "Has grabado con Sprout durante %d días", ru: "Вы записывали в Sprout в течение %d дней", ko: "Sprout으로 %d일 동안 기록했습니다" },
  "This Year's Heatmap": { fr: "Carte de chaleur de cette année", "es-419": "Mapa de calor de este año", ru: "Тепловая карта этого года", ko: "올해 히트맵" },
  "Memory Overview": { fr: "Aperçu de la mémoire", "es-419": "Resumen de memoria", ru: "Обзор памяти", ko: "기억 개요" },
  "Most Mentioned People": { fr: "Personnes les plus mentionnées", "es-419": "Personas más mencionadas", ru: "Самые упоминаемые люди", ko: "가장 많이 언급된 사람" },
  "About Screen": { fr: "Écran À propos", "es-419": "Pantalla Acerca de", ru: "Экран О приложении", ko: "정보 화면" },
  "Rating Screen": { fr: "Écran de notation", "es-419": "Pantalla de calificación", ru: "Экран оценки", ko: "평점 화면" },
  "Free": { fr: "Gratuit", "es-419": "Gratis", ru: "Бесплатно", ko: "무료" },
  "Grow Active": { fr: "Grow Actif", "es-419": "Grow Activo", ru: "Grow Активен", ko: "Grow 활성" },
  "Username": { fr: "Nom d'utilisateur", "es-419": "Nombre de usuario", ru: "Имя пользователя", ko: "사용자 이름" },
  "%d days": { fr: "%d jours", "es-419": "%d días", ru: "%d дней", ko: "%d일" },
  "App Language": { fr: "Langue de l'application", "es-419": "Idioma de la aplicación", ru: "Язык приложения", ko: "앱 언어" },
  "Appearance": { fr: "Apparence", "es-419": "Apariencia", ru: "Внешний вид", ko: "외관" },
  "Face ID / Touch ID Lock": { fr: "Verrouillage Face ID / Touch ID", "es-419": "Bloqueo Face ID / Touch ID", ru: "Блокировка Face ID / Touch ID", ko: "Face ID / Touch ID 잠금" },
  "Daily Prompt Time": { fr: "Heure du prompt quotidien", "es-419: "Hora del prompt diario", ru: "Время ежедневного запроса", ko: "일일 프롬프트 시간" },
  "Export Data (JSON)": { fr: "Exporter les données (JSON)", "es-419": "Exportar datos (JSON)", ru: "Экспорт данных (JSON)", ko: "데이터 내보내기 (JSON)" },
  "Login Method": { fr: "Méthode de connexion", "es-419": "Método de inicio de sesión", ru: "Способ входа", ko: "로그인 방법" },
  "Signed in": { fr: "Connecté", "es-419": "Sesión iniciada", ru: "Вход выполнен", ko: "로그인됨" },
  "About": { fr: "À propos", "es-419": "Acerca de", ru: "О приложении", ko: "정보" },
  "Apple": { fr: "Apple", "es-419": "Apple", ru: "Apple", ko: "Apple" },
  "Email": { fr: "E-mail", "es-419": "Correo electrónico", ru: "Эл. почта", ko: "이메일" },
  "Google": { fr: "Google", "es-419": "Google", ru: "Google", ko: "Google" },
  "Log Out": { fr: "Se déconnecter", "es-419": "Cerrar sesión", ru: "Выйти", ko: "로그아웃" },
  "Rate Sprout": { fr: "Noter Sprout", "es-419": "Calificar Sprout", ru: "Оценить Sprout", ko: "Sprout 평가" },
  "Version": { fr: "Version", "es-419": "Versión", ru: "Версия", ko: "버전" },
  "Personal Settings": { fr: "Paramètres personnels", "es-419": "Configuración personal", ru: "Личные настройки", ko: "개인 설정" },
  "Privacy & Security": { fr: "Confidentialité et sécurité", "es-419": "Privacidad y seguridad", ru: "Конфиденциальность и безопасность", ko: "개인정보 보호 및 보안" },
  "Subscription": { fr: "Abonnement", "es-419": "Suscripción", ru: "Подписка", ko: "구독" },
  "Account": { fr: "Compte", "es-419": "Cuenta", ru: "Аккаунт", ko: "계정" },
  "Unlock": { fr: "Déverrouiller", "es-419": "Desbloquear", ru: "Разблокировать", ko: "잠금 해제" },
  "Biometric Lock": { fr: "Verrouillage biométrique", "es-419": "Bloqueo biométrico", ru: "Биометрическая блокировка", ko: "생체 인증 잠금" },
  "Face ID": { fr: "Face ID", "es-419": "Face ID", ru: "Face ID", ko: "Face ID" },
  "Touch ID": { fr: "Touch ID", "es-419": "Touch ID", ru: "Touch ID", ko: "Touch ID" },
  "Authenticate to enable biometric lock.": { fr: "Authentifiez-vous pour activer le verrouillage biométrique.", "es-419": "Autentícate para activar el bloqueo biométrico.", ru: "Аутентифицируйтесь для включения биометрической блокировки.", ko: "생체 인증 잠금을 활성화하려면 인증하세요." },
  "Unlock Sprout.": { fr: "Déverrouiller Sprout.", "es-419": "Desbloquear Sprout.", ru: "Разблокировать Sprout.", ko: "Sprout 잠금 해제." },
  "Face ID Lock": { fr: "Verrouillage Face ID", "es-419": "Bloqueo Face ID", ru: "Блокировка Face ID", ko: "Face ID 잠금" },
  "Touch ID Lock": { fr: "Verrouillage Touch ID", "es-419": "Bloqueo Touch ID", ru: "Блокировка Touch ID", ko: "Touch ID 잠금" },
};

const files = [
  'Account.xcstrings',
  'AddCard.xcstrings',
  'Cards.xcstrings',
  'Common.xcstrings',
  'Content.xcstrings',
  'Detail.xcstrings',
  'InfoPlist.xcstrings',
  'Subscription.xcstrings',
  'Toolbar.xcstrings'
];

const untranslatedLangs = ['fr', 'es-419', 'ru', 'ko'];

function processFile(filePath) {
  const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  let changed = false;

  for (const [key, value] of Object.entries(content.strings)) {
    for (const lang of untranslatedLangs) {
      if (value.localizations && value.localizations[lang]) {
        const entry = value.localizations[lang];
        if (entry.stringUnit && entry.stringUnit.state === 'new') {
          const englishValue = value.localizations.en?.stringUnit?.value;
          if (englishValue && translations[englishValue]) {
            const translated = translations[englishValue][lang];
            if (translated) {
              entry.stringUnit.value = translated;
              entry.stringUnit.state = 'translated';
              changed = true;
            }
          }
        }
      }
    }
  }

  if (changed) {
    fs.writeFileSync(filePath, JSON.stringify(content, null, 2), 'utf8');
    console.log(`Updated: ${path.basename(filePath)}`);
  }

  return changed;
}

function main() {
  console.log('Starting translation...\n');

  let totalChanged = 0;
  for (const file of files) {
    const filePath = path.join(__dirname, 'sprout/sprout', file);
    if (processFile(filePath)) {
      totalChanged++;
    }
  }

  console.log(`\nDone! Updated ${totalChanged} files.`);
}

main();
