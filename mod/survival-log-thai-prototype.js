(function () {
    'use strict';

    const thai = {
        continueText: 'เล่นต่อ',
        newGameText: 'เริ่มเกมใหม่',
        pureEndlessText: 'โหมดไม่รู้จบ',
        loadGameText: 'โหลดเกม',
        settingsText: 'ตั้งค่า',
        exitText: 'ออกจากเกม',
        settingsLanguage: 'ภาษา',
        settingsChinese: '中文',
        settingsEnglish: 'ไทย (ต้นแบบ)',
        settingsMusic: 'เสียงดนตรี',
        settingsSound: 'เสียงเอฟเฟกต์',
        settingsWindowMode: 'โหมดหน้าจอ',
        settingsResolution: 'ความละเอียด',
        wmBorderless: 'เต็มจอไร้ขอบ',
        wmExclusive: 'เต็มจอ',
        wmWindowed: 'หน้าต่าง',
        settingsGraphics: 'คุณภาพกราฟิก',
        qualityLow: 'ต่ำ',
        qualityMedium: 'กลาง',
        qualityHigh: 'สูง',
        settingsFrameRate: 'อัตราเฟรม',
        frameRateUnlimited: 'ไม่จำกัด',
        advancedSettingsText: 'ตั้งค่าขั้นสูง',
        advApplyText: 'นำไปใช้',
        confirmTitle: 'ยืนยัน',
        confirmCancel: 'ยกเลิก',
        confirmOk: 'ยืนยัน',
        achievementTitle: 'ความสำเร็จ',
        endlessUnlockedBadge: 'ปลดล็อกแล้ว'
    };

    function isEnglishPayload(data) {
        return data && /english/i.test(String(data.settingsEnglish || ''));
    }

    window.SLThaiPrototype = {
        applyLocalization: function (data) {
            const source = data || {};
            if (isEnglishPayload(source)) {
                document.documentElement.classList.add('sl-thai-active');
                document.documentElement.lang = 'th';
                return Object.assign({}, source, thai);
            }
            document.documentElement.classList.remove('sl-thai-active');
            document.documentElement.lang = 'zh';
            return Object.assign({}, source, { settingsEnglish: thai.settingsEnglish });
        }
    };

    const style = document.createElement('style');
    style.textContent = [
        'html.sl-thai-active body,html.sl-thai-active #app{font-family:"Leelawadee UI","Tahoma","Noto Sans Thai","Microsoft YaHei",sans-serif!important}',
        'html.sl-thai-active [data-i18n],html.sl-thai-active .menu-text,html.sl-thai-active .menu-sub,html.sl-thai-active .menu-cond,html.sl-thai-active .lang-option{letter-spacing:0!important;word-spacing:normal!important;line-height:1.35!important}',
        'html.sl-thai-active .menu-text{font-weight:700}',
        'html.sl-thai-active .settings-label{line-height:1.45!important}'
    ].join('');
    document.head.appendChild(style);
})();
