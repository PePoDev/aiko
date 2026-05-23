// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'Aiko';

  @override
  String get appSubtitle => 'เพื่อนคู่ใจทางการเงินของคุณ';

  @override
  String get homeTab => 'ภาพรวม';

  @override
  String get transactionsTab => 'รายการ';

  @override
  String get budgetTab => 'งบประมาณ';

  @override
  String get insightsTab => 'ข้อมูลเชิงลึก';

  @override
  String get aikoTab => 'Aiko';

  @override
  String get moreTab => 'เพิ่มเติม';

  @override
  String get save => 'บันทึก';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get delete => 'ลบ';

  @override
  String get edit => 'แก้ไข';

  @override
  String get add => 'เพิ่ม';

  @override
  String get close => 'ปิด';

  @override
  String get continueButton => 'ดำเนินการต่อ';

  @override
  String get back => 'กลับ';

  @override
  String get done => 'เสร็จสิ้น';

  @override
  String get ok => 'ตกลง';

  @override
  String get yes => 'ใช่';

  @override
  String get no => 'ไม่ใช่';

  @override
  String get confirm => 'ยืนยัน';

  @override
  String get retry => 'ลองอีกครั้ง';

  @override
  String get refresh => 'รีเฟรช';

  @override
  String get search => 'ค้นหา';

  @override
  String get filter => 'กรอง';

  @override
  String get sort => 'เรียงลำดับ';

  @override
  String get loading => 'กำลังโหลด';

  @override
  String get error => 'ข้อผิดพลาด';

  @override
  String get success => 'สำเร็จ';

  @override
  String get overview => 'ภาพรวม';

  @override
  String get aikoHub => 'ศูนย์กลาง Aiko';

  @override
  String get aikoHubDescription =>
      'ฟีเจอร์ทั้งหมดจัดกลุ่มไว้ที่นี่ เพื่อให้เข้าถึงหน้าเพจรองได้โดยไม่ทำให้แท็บหลักแออัด';

  @override
  String get hiAiko => 'สวัสดี ฉันคือ Aiko';

  @override
  String get safeToSpend => 'ปลอดภัยที่จะใช้จ่าย';

  @override
  String safeToSpendDescription(String amount) {
    return 'คุณมี $amount โดยประมาณที่ปลอดภัยสำหรับใช้จ่ายในสัปดาห์นี้ นี่เป็นเพียงการประเมิน ดังนั้นควรจดจำค่าใช้จ่ายและการซื้อที่วางแผนไว้';
  }

  @override
  String get safeToSpendWeekly =>
      'เงินสำรองรายสัปดาห์คำนวณจากรายการที่บันทึกแล้ว';

  @override
  String get monthlyCashFlow => 'กระแสเงินสดรายเดือน';

  @override
  String get income => 'รายได้';

  @override
  String get spending => 'รายจ่าย';

  @override
  String get pace => 'จังหวะ';

  @override
  String get paceAhead => 'การใช้จ่ายเร็วกว่าจังหวะงบประมาณปัจจุบัน';

  @override
  String get paceOnTrack => 'การใช้จ่ายอยู่ในจังหวะของงบประมาณปัจจุบัน';

  @override
  String get financialPyramid => 'พีระมิดการเงิน';

  @override
  String currentHealth(String level) {
    return 'สุขภาพการเงินปัจจุบัน: $level';
  }

  @override
  String pyramidFit(int percent) {
    return 'เหมาะสม $percent%';
  }

  @override
  String get pyramidBuildBase =>
      'สร้างฐานให้แข็งแรงก่อน จากนั้นค่อยไต่ระดับทีละชั้น';

  @override
  String get pyramidLevel1 => 'ระดับ 1 (ฐาน)';

  @override
  String get pyramidLevel1Desc =>
      'หารายได้เพียงพอสำหรับภาระผูกพันรายเดือน ซื้อประกันสุขภาพ และสร้างกองทุนฉุกเฉิน';

  @override
  String get pyramidLevel2 => 'ระดับ 2';

  @override
  String get pyramidLevel2Desc =>
      'เพิ่มรายได้ ซื้อประกันชีวิตและประกันทุพพลภาพ ชำระหนี้ที่มีดอกเบี้ยสูง และเริ่มออมเงินเพื่อเกษียณ';

  @override
  String get pyramidLevel3 => 'ระดับ 3';

  @override
  String get pyramidLevel3Desc =>
      'ซื้อบ้าน ชำระหนี้ที่มีดอกเบี้ยต่ำ จัดหาให้ลูกๆ และเพิ่มการออมเพื่อเกษียณ';

  @override
  String get pyramidLevel4 => 'ระดับ 4';

  @override
  String get pyramidLevel4Desc =>
      'ดูแลพ่อแม่ที่แก่ชรา ออมเงินค่าเล่าเรียนบุตร ชำระค่าจำนองก่อนเกษียณ เพิ่มการออมเพื่อเกษียณสูงสุด และพิจารณาประกันการดูแลระยะยาว';

  @override
  String get pyramidLevel5 => 'ระดับ 5 (ยอดสูงสุด)';

  @override
  String get pyramidLevel5Desc =>
      'เกษียณและสร้างกลยุทธ์รายได้หลังเกษียณ ทำตามความฝัน บริจาคเงิน และวางแผนมรดก';

  @override
  String get upcomingDueDates => 'วันครบกำหนดที่จะถึง';

  @override
  String get loadingBills => 'กำลังโหลดบิลและการชำระบัตร...';

  @override
  String get unableToLoadDueDates => 'ไม่สามารถโหลดวันครบกำหนดได้ในขณะนี้';

  @override
  String get quickAdd => 'เพิ่มด่วน';

  @override
  String get addTransaction => 'รายการ';

  @override
  String get addBudget => 'งบประมาณ';

  @override
  String get settingsTitle => 'การตั้งค่า';

  @override
  String get profile => 'โปรไฟล์';

  @override
  String get profileAndPrivacy => 'โปรไฟล์และความเป็นส่วนตัว';

  @override
  String get personalInformation => 'ข้อมูลส่วนบุคคล';

  @override
  String get displayName => 'ชื่อที่แสดง';

  @override
  String get email => 'อีเมล';

  @override
  String get baseCurrency => 'สกุลเงินหลัก';

  @override
  String get country => 'ประเทศ';

  @override
  String get preferredTheme => 'ธีมที่ต้องการ';

  @override
  String get themeSystem => 'ระบบ';

  @override
  String get themeLight => 'สว่าง';

  @override
  String get themeDark => 'มืด';

  @override
  String get aiConsent => 'ยินยอม AI';

  @override
  String get aiConsentDescription =>
      'อนุญาตให้ Aiko วิเคราะห์ข้อมูลการเงินที่ละเอียดอ่อนเพื่อข้อมูลเชิงลึก';

  @override
  String get security => 'ความปลอดภัย';

  @override
  String get securityAndPinLock => 'ความปลอดภัยและล็อค PIN';

  @override
  String get pinLockDescription =>
      'ปกป้องข้อมูลการเงินส่วนตัวของคุณด้วยการตั้งรหัส PIN 4 หลักที่ปลอดภัย';

  @override
  String get enterPin => 'ใส่ PIN 4 หลัก';

  @override
  String get pinConfigured => 'ตั้งค่า PIN สำเร็จ!';

  @override
  String get pinMustBe4Digits => 'PIN ต้องเป็นตัวเลข 4 หลักเท่านั้น';

  @override
  String get pinEnabled => 'เปิดใช้งานล็อค PIN แล้ว';

  @override
  String get removePinLock => 'ลบล็อค PIN';

  @override
  String get disablePinConfirm =>
      'คุณแน่ใจหรือไม่ว่าต้องการลบล็อค PIN? การกระทำนี้จะลดความปลอดภัยของข้อมูลการเงินของคุณ';

  @override
  String get pinRemoved => 'ลบล็อค PIN แล้ว';

  @override
  String get biometricsEnabled =>
      'เปิดใช้งานการยืนยันตัวตนด้วยไบโอเมตริกซ์แล้ว';

  @override
  String get enableBiometrics => 'เปิดใช้งานไบโอเมตริกซ์';

  @override
  String get disableBiometrics => 'ปิดใช้งานไบโอเมตริกซ์';

  @override
  String get biometricsConfigured => 'เปิดใช้งานไบโอเมตริกซ์แล้ว!';

  @override
  String get biometricsRemoved => 'ปิดใช้งานไบโอเมตริกซ์แล้ว';

  @override
  String get accountManagement => 'การจัดการบัญชี';

  @override
  String get signOut => 'ออกจากระบบ';

  @override
  String get signingOut => 'กำลังออกจากระบบ...';

  @override
  String get signedOut => 'ออกจากระบบสำเร็จ';

  @override
  String get deleteAccount => 'ลบบัญชี';

  @override
  String get deletingAccount => 'กำลังลบบัญชี...';

  @override
  String get deleteAccountConfirm =>
      'คุณแน่ใจหรือไม่ว่าต้องการลบบัญชีของคุณอย่างถาวร? การกระทำนี้ไม่สามารถยกเลิกได้';

  @override
  String get accountDeleted => 'ลบบัญชีแล้ว!';

  @override
  String get profileUpdated => 'อัปเดตโปรไฟล์แล้ว!';

  @override
  String failedToSaveProfile(String error) {
    return 'บันทึกโปรไฟล์ไม่สำเร็จ: $error';
  }

  @override
  String get couldNotLoadProfile => 'ไม่สามารถโหลดโปรไฟล์ของคุณได้';

  @override
  String get welcomeToAiko => 'ยินดีต้อนรับสู่ Aiko';

  @override
  String get signIn => 'เข้าสู่ระบบ';

  @override
  String get signUp => 'ลงทะเบียน';

  @override
  String get signInWithEmail => 'เข้าสู่ระบบด้วยอีเมล';

  @override
  String get signUpWithEmail => 'ลงทะเบียนด้วยอีเมล';

  @override
  String get emailAddress => 'ที่อยู่อีเมล';

  @override
  String get password => 'รหัสผ่าน';

  @override
  String get forgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get dontHaveAccount => 'ยังไม่มีบัญชี?';

  @override
  String get alreadyHaveAccount => 'มีบัญชีอยู่แล้ว?';

  @override
  String get createAccount => 'สร้างบัญชี';

  @override
  String get sendResetLink => 'ส่งลิงก์รีเซ็ต';

  @override
  String get backToSignIn => 'กลับไปเข้าสู่ระบบ';

  @override
  String get checkYourEmail => 'ตรวจสอบอีเมลของคุณ';

  @override
  String get resetLinkSent => 'เราได้ส่งลิงก์รีเซ็ตรหัสผ่านให้คุณแล้ว';

  @override
  String get welcomeToAikoOnboarding => 'ยินดีต้อนรับสู่ Aiko';

  @override
  String get meetAiko => 'พบกับ Aiko';

  @override
  String get aikoPersonalityTone => 'น้ำเสียงบุคลิกของ Aiko';

  @override
  String get personalitySupportive => 'สนับสนุน';

  @override
  String get personalitySupportiveDesc =>
      'เพื่อนทางการเงินที่อบอุ่น ให้กำลังใจ ไม่ตัดสิน';

  @override
  String get personalityProfessional => 'มืออาชีพ';

  @override
  String get personalityProfessionalDesc =>
      'ที่ปรึกษาการเงินที่เน้นวิเคราะห์ จริงจัง ขับเคลื่อนด้วยข้อมูล';

  @override
  String get personalityPlayful => 'สนุกสนาน';

  @override
  String get personalityPlayfulDesc =>
      'มีพลัง สนุก เฉลิมฉลองชัยชนะเล็กๆ ด้วยไฮไฟว์';

  @override
  String get mainFinancialGoal => 'เป้าหมายทางการเงินหลักของคุณคืออะไร?';

  @override
  String get goalSaveMoney => 'ออมเงิน';

  @override
  String get goalSaveMoneyDesc => 'สร้างเงินสำรองฉุกเฉินที่แข็งแกร่ง';

  @override
  String get goalTrackSpending => 'ติดตามการใช้จ่าย';

  @override
  String get goalTrackSpendingDesc => 'บันทึกค่าใช้จ่ายเพื่อดูว่าเงินไปไหนบ้าง';

  @override
  String get goalPayOffDebt => 'ชำระหนี้';

  @override
  String get goalPayOffDebtDesc => 'สร้างแผนชำระหนี้เพื่อปลอดหนี้';

  @override
  String get goalBuildWealth => 'สร้างความมั่งคั่ง';

  @override
  String get goalBuildWealthDesc =>
      'ลงทุนอย่างชาญฉลาดและวางแผนการเติบโตระยะยาว';

  @override
  String get currencyAndCountrySettings => 'การตั้งค่าสกุลเงินและประเทศ';

  @override
  String get addFirstAccount => 'เพิ่มบัญชีการเงินแรกของคุณ';

  @override
  String get accountName => 'ชื่อบัญชี';

  @override
  String get accountNameHint => 'เช่น กระเป๋าเงิน บัญชีเช็ค';

  @override
  String get accountType => 'ประเภทบัญชี';

  @override
  String get accountTypeCash => 'กระเป๋าเงินสด';

  @override
  String get accountTypeBank => 'บัญชีธนาคาร';

  @override
  String get accountTypeCreditCard => 'บัตรเครดิต';

  @override
  String get accountTypeInvestment => 'การลงทุน';

  @override
  String get openingBalance => 'ยอดเปิดบัญชี';

  @override
  String get accountNameRequired => 'กรุณาใส่ชื่อบัญชี';

  @override
  String get balanceRequired => 'กรุณาใส่ยอดเริ่มต้น';

  @override
  String get balanceMustBeValid => 'ต้องเป็นตัวเลขบวกที่ถูกต้อง';

  @override
  String get configureSecurity => 'ตั้งค่าการรักษาความปลอดภัย';

  @override
  String get securePinCode => 'รหัส PIN ที่ปลอดภัย';

  @override
  String get biometricsOnly => 'ไบโอเมตริกซ์เท่านั้น';

  @override
  String get enter4DigitPin => 'ใส่รหัส PIN 4 หลัก';

  @override
  String get useDeviceBiometrics => 'ใช้ไบโอเมตริกซ์ของอุปกรณ์';

  @override
  String get biometricsDescription =>
      'ใช้ Face ID / Touch ID / สแกนลายนิ้วมือ Android อย่างปลอดภัยเพื่อปลดล็อค Aiko ทันที';

  @override
  String get finishAndSignIn => 'เสร็จสิ้นและเข้าสู่ระบบ';

  @override
  String get enterFullPin => 'กรุณาใส่รหัส PIN 4 หลักให้ครบ';

  @override
  String get transactions => 'รายการ';

  @override
  String get addNewTransaction => 'เพิ่มรายการใหม่';

  @override
  String get editTransaction => 'แก้ไขรายการ';

  @override
  String get transactionDetails => 'รายละเอียดรายการ';

  @override
  String get amount => 'จำนวนเงิน';

  @override
  String get date => 'วันที่';

  @override
  String get category => 'หมวดหมู่';

  @override
  String get account => 'บัญชี';

  @override
  String get description => 'คำอธิบาย';

  @override
  String get notes => 'หมายเหตุ';

  @override
  String get type => 'ประเภท';

  @override
  String get typeIncome => 'รายได้';

  @override
  String get typeExpense => 'รายจ่าย';

  @override
  String get typeTransfer => 'โอนเงิน';

  @override
  String get recurring => 'ทำซ้ำ';

  @override
  String get recurringTransaction => 'รายการทำซ้ำ';

  @override
  String get tags => 'แท็ก';

  @override
  String get attachments => 'ไฟล์แนบ';

  @override
  String get receipt => 'ใบเสร็จ';

  @override
  String get addReceipt => 'เพิ่มใบเสร็จ';

  @override
  String get scanReceipt => 'สแกนใบเสร็จ';

  @override
  String get transactionSaved => 'บันทึกรายการแล้ว!';

  @override
  String get transactionDeleted => 'ลบรายการแล้ว!';

  @override
  String get deleteTransactionConfirm =>
      'คุณแน่ใจหรือไม่ว่าต้องการลบรายการนี้?';

  @override
  String get budgets => 'งบประมาณ';

  @override
  String get addBudgetItem => 'เพิ่มงบประมาณ';

  @override
  String get editBudgetItem => 'แก้ไขงบประมาณ';

  @override
  String get budgetName => 'ชื่องบประมาณ';

  @override
  String get budgetAmount => 'จำนวนงบประมาณ';

  @override
  String get period => 'ช่วงเวลา';

  @override
  String get periodMonthly => 'รายเดือน';

  @override
  String get periodWeekly => 'รายสัปดาห์';

  @override
  String get periodYearly => 'รายปี';

  @override
  String get spent => 'ใช้ไป';

  @override
  String get remaining => 'เหลือ';

  @override
  String get budgetProgress => 'ความคืบหน้างบประมาณ';

  @override
  String get overBudget => 'เกินงบประมาณ';

  @override
  String get onTrack => 'อยู่ในเป้า';

  @override
  String get budgetSaved => 'บันทึกงบประมาณแล้ว!';

  @override
  String get budgetDeleted => 'ลบงบประมาณแล้ว!';

  @override
  String get goals => 'เป้าหมาย';

  @override
  String get savingGoals => 'เป้าหมายการออม';

  @override
  String get addGoal => 'เพิ่มเป้าหมาย';

  @override
  String get editGoal => 'แก้ไขเป้าหมาย';

  @override
  String get goalName => 'ชื่อเป้าหมาย';

  @override
  String get targetAmount => 'จำนวนเป้าหมาย';

  @override
  String get currentAmount => 'จำนวนปัจจุบัน';

  @override
  String get targetDate => 'วันที่เป้าหมาย';

  @override
  String get goalProgress => 'ความคืบหน้าเป้าหมาย';

  @override
  String daysRemaining(int days) {
    return 'เหลืออีก $days วัน';
  }

  @override
  String get goalAchieved => 'บรรลุเป้าหมาย!';

  @override
  String get goalSaved => 'บันทึกเป้าหมายแล้ว!';

  @override
  String get goalDeleted => 'ลบเป้าหมายแล้ว!';

  @override
  String get accounts => 'บัญชี';

  @override
  String get addAccountItem => 'เพิ่มบัญชี';

  @override
  String get editAccountItem => 'แก้ไขบัญชี';

  @override
  String get accountBalance => 'ยอดคงเหลือบัญชี';

  @override
  String get totalBalance => 'ยอดคงเหลือทั้งหมด';

  @override
  String get activeAccounts => 'บัญชีที่ใช้งาน';

  @override
  String get accountSaved => 'บันทึกบัญชีแล้ว!';

  @override
  String get insights => 'ข้อมูลเชิงลึก';

  @override
  String get spendingAnalysis => 'การวิเคราะห์รายจ่าย';

  @override
  String get incomeAnalysis => 'การวิเคราะห์รายได้';

  @override
  String get trends => 'แนวโน้ม';

  @override
  String get categoryBreakdown => 'รายละเอียดตามหมวดหมู่';

  @override
  String get topCategories => 'หมวดหมู่ยอดนิยม';

  @override
  String get thisMonth => 'เดือนนี้';

  @override
  String get lastMonth => 'เดือนที่แล้ว';

  @override
  String get thisYear => 'ปีนี้';

  @override
  String get exportTitle => 'ส่งออก';

  @override
  String get exportData => 'ส่งออกข้อมูล';

  @override
  String get exportFormat => 'รูปแบบการส่งออก';

  @override
  String get exportPeriod => 'ช่วงเวลาส่งออก';

  @override
  String get exportAllData => 'ส่งออกข้อมูลทั้งหมด';

  @override
  String get exportCustomRange => 'กำหนดช่วงเอง';

  @override
  String get startDate => 'วันที่เริ่มต้น';

  @override
  String get endDate => 'วันที่สิ้นสุด';

  @override
  String get exportComplete => 'ส่งออกเสร็จสมบูรณ์!';

  @override
  String get learningHubTitle => 'ศูนย์การเรียนรู้';

  @override
  String get articles => 'บทความ';

  @override
  String get tutorials => 'บทช่วยสอน';

  @override
  String get guides => 'คู่มือ';

  @override
  String get privacyTitle => 'โปรไฟล์และความเป็นส่วนตัว';

  @override
  String get aiDisclaimer =>
      'Aiko ให้การประเมินเท่านั้น ไม่ใช่คำแนะนำทางการเงินที่ได้รับการรับรอง';

  @override
  String get noDueDates => 'ไม่มีวันครบกำหนดที่จะถึง';

  @override
  String get noTransactions => 'ยังไม่มีรายการ';

  @override
  String get noBudgets => 'ยังไม่มีงบประมาณ';

  @override
  String get noGoals => 'ยังไม่มีเป้าหมาย';

  @override
  String get noAccounts => 'ยังไม่มีบัญชี';

  @override
  String get dashboardUnavailable => 'แดชบอร์ดไม่พร้อมใช้งาน';

  @override
  String get dashboardUnavailableMessage =>
      'Aiko ไม่สามารถโหลด Supabase workspace ของคุณได้';

  @override
  String get total => 'ทั้งหมด';

  @override
  String get average => 'เฉลี่ย';

  @override
  String get currency => 'สกุลเงิน';

  @override
  String get timezone => 'เขตเวลา';

  @override
  String get language => 'ภาษา';

  @override
  String get notifications => 'การแจ้งเตือน';

  @override
  String get help => 'ความช่วยเหลือ';

  @override
  String get about => 'เกี่ยวกับ';

  @override
  String get version => 'เวอร์ชัน';

  @override
  String get termsOfService => 'ข้อกำหนดการให้บริการ';

  @override
  String get privacyPolicy => 'นโยบายความเป็นส่วนตัว';
}
