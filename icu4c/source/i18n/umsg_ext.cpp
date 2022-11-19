
#if !UCONFIG_NO_FORMATTING
#include "unicode/utypes.h"
#include "unicode/msgfmt.h"

U_NAMESPACE_USE

U_CAPI void icu_msgSample1(){
#define dataerrln(...) printf("[ERROR]" __VA_ARGS__)
#define errln(msg) printf(msg)
#define logln(...)

    UErrorCode err = U_ZERO_ERROR;
    UnicodeString t1("{1} {0, plural, one{C''est # fichier {1}} other{Ce sont # fichiers}} dans la liste. {0,selectordinal,one{#st}two{#nd}other{#VVV}} {2,select,varsh{{3,selectordinal,one{#ll}two{#rr}few{#ttt}many{#TTT}other{#VVV}} vrh} other{{3,selectordinal,one{#lī}two{#rī}few{#thī}many{#Thī}other{#vīn}} {2}}}");
    UnicodeString t2("{norm} {argument, plural, one{C''est # fichier {norm}} other {Ce sont # fichiers}} dans la liste. "
                     "\n{noun, select, varsh {{count, selectordinal, one{#lā} two{#rā} few{#thā} many{#Thā} other {#vān} } vrh}"
                     "                 other {{count, selectordinal, one{#lī} two{#rī} few{#thī} many{#Thī} other {#vīn} } {noun}} }"
                     "\nMy OKR progress is {count, number, percent} complete"
                     "\nToday is {nowTime, date, full}, time is {nowTime, time, full}"
                     "\n{noun, select, varsh {He} other {She} } likes programming"
                     );
    UnicodeString t3("There {0, plural, one{is # zavod}few{are {0, number,###.0} zavoda} other{are # zavodov}} in the directory.");
    UnicodeString t4("There {argument, plural, one{is # zavod}few{are {argument, number,###.0} zavoda} other{are #zavodov}} in the directory.");
    UnicodeString t5("{0, plural, one {{0, number,C''est #,##0.0# fichier}} other {Ce sont # fichiers}} dans la liste.");
    MessageFormat mfNum { t1, Locale("hi_IN"), err };
    if (U_FAILURE(err)) {
        dataerrln("msgSample1 mfnum - %s", u_errorName(err));
        return;
    }
    Formattable a { UnicodeString{"xxx"} };
    Formattable testArgs1[] = { (int32_t)10000, UnicodeString{"你好"}, UnicodeString{"varsh"}, (int32_t)2, {3600 * 24 * 9 * 1000, Formattable::kIsDate} };
    // Formattable testArgs1[] = { (int32_t)0, "hello", "varsh", "2" };
    FieldPosition ignore(FieldPosition::DONT_CARE);
    UnicodeString numResult1;
    mfNum.format(testArgs1, 5, numResult1, ignore, err);

    MessageFormat mfAlpha = MessageFormat(t2, Locale("en-CN"), err);
    UnicodeString argName[] {UnicodeString{"argument"}, UnicodeString{"norm"}, UnicodeString{"noun"}, UnicodeString{"count"}, UnicodeString{"nowTime"}};
    UnicodeString argNameResult;
    mfAlpha.format(argName, testArgs1, 5, argNameResult, err);
    if (U_FAILURE(err)) {
        dataerrln("mfAlpha.format - %s", u_errorName(err));
        return;
    }
//    if ( numResult1 != argNameResult){
//        errln("TestMessageFormat::testMsgFormatPlural #1 not equal");
//        logln(UnicodeString("The results of argumentName and argumentIndex are not the same."));
//    }
//    if ( numResult1 != UnicodeString("hello C\'est 0 fichier hello dans la liste.")) {
//        errln("TestMessageFormat::testMsgFormatPlural #1 != output ");
//        logln(UnicodeString("The results of argumentName and argumentIndex are not the same."));
//    }
    err = U_ZERO_ERROR;

    MessageFormat m(UnicodeString{
                        "{0,plural,one{1 file}other{# files}}, "
                        "{0,selectordinal,one{#st file}two{#nd file}few{#rd file}other{#th file}},"
                        "{3,selectordinal,one{#st}two{#nd}other{#VVV}}"
                    }, Locale{"zh_CN"}, err);

    if (U_FAILURE(err)) {
        dataerrln("total - %s", u_errorName(err));
        return;
    }

    Formattable args[] = { (int32_t)21, UnicodeString{"hello"}, UnicodeString{"varsh"}, (int32_t)2, (int32_t)2 };;
    UnicodeString result;
    m.format(args, 5, result, ignore, err);
    if (U_FAILURE(err)) {
        dataerrln("format - %s", u_errorName(err));
        return;
    }

    args[0].setLong(2);
    m.format(args, 5, result.remove(), ignore, err);
    if (U_FAILURE(err)) {
        dataerrln("format 2 - %s", u_errorName(err));
        return;
    }

    args[0].setLong(1);
    m.format(args, 5, result.remove(), ignore, err);
    if (U_FAILURE(err)) {
        dataerrln("format 1 - %s", u_errorName(err));
        return;
    }

    args[0].setLong(3);
    m.format(args, 5, result.remove(), ignore, err);
    if (U_FAILURE(err)) {
        dataerrln("format 3 - %s", u_errorName(err));
        return;
    }
    printf("[Info] all simple test success");
}
#endif
