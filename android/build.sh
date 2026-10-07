#!/usr/bin/env bash
# Construit dist/section-acier.apk : une WebView qui embarque ../index.html.
# N'utilise pas le SDK Android : les outils viennent de Maven Central
#   - aapt2 + ressources du framework : org.apktool:apktool-lib
#   - classes android.jar (API 16)   : com.google.android:android
#   - dx (dex)                       : com.jakewharton.android.repackaged:dalvik-dx
#   - signature v2                   : com.android.tools.build:apksig
# Prérequis : JDK 11+, python3 + Pillow, curl, unzip, zip.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$(pwd)
TOOLS=$ROOT/.tools
BUILD=$ROOT/build
OUT=$ROOT/../dist/section-acier.apk
M=https://repo.maven.apache.org/maven2

mkdir -p "$TOOLS"
fetch() { [ -f "$TOOLS/$2" ] || curl -sSfL --retry 4 -o "$TOOLS/$2" "$M/$1"; }
fetch org/apktool/apktool-lib/3.0.3/apktool-lib-3.0.3.jar apktool-lib.jar
fetch com/google/android/android/4.1.1.4/android-4.1.1.4.jar android.jar
fetch com/jakewharton/android/repackaged/dalvik-dx/16.0.1/dalvik-dx-16.0.1.jar dx.jar
fetch com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar apksig.jar
if [ ! -x "$TOOLS/aapt2" ]; then
  unzip -oqj "$TOOLS/apktool-lib.jar" prebuilt/linux/aapt2 prebuilt/android-framework.jar -d "$TOOLS"
  chmod +x "$TOOLS/aapt2"
fi

rm -rf "$BUILD" && mkdir -p "$BUILD"/{res,classes,assets,flat}
python3 make_icons.py "$BUILD/res"
cp ../index.html "$BUILD/assets/index.html"

# 1. Ressources + manifeste
"$TOOLS/aapt2" compile --dir "$BUILD/res" -o "$BUILD/flat/res.zip"
"$TOOLS/aapt2" link -I "$TOOLS/android-framework.jar" --manifest AndroidManifest.xml \
  -A "$BUILD/assets" -o "$BUILD/base.apk" "$BUILD/flat/res.zip"

# 2. Java -> .class -> classes.dex
#    dx ne lit que le bytecode Java 7 (version 51) : on compile en Java 8 sans
#    lambda puis on abaisse le numéro de version des .class.
javac -nowarn --release 8 -Xlint:-options -cp "$TOOLS/android.jar" -d "$BUILD/classes" $(find src -name '*.java')
find "$BUILD/classes" -name '*.class' -exec python3 -c '
import sys
for f in sys.argv[1:]:
    b = bytearray(open(f, "rb").read()); b[6:8] = (51).to_bytes(2, "big"); open(f, "wb").write(b)
' {} +
java -cp "$TOOLS/dx.jar" com.android.dx.command.Main --dex --output="$BUILD/classes.dex" "$BUILD/classes"
(cd "$BUILD" && zip -q base.apk classes.dex)
python3 zipalign.py "$BUILD/base.apk" "$BUILD/aligned.apk"

# 3. Signature v2 (APK Signature Scheme v2, Android 7+ ; clé locale android/release.keystore, créée au premier build)
KS=$ROOT/release.keystore
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass sectionacier -keypass sectionacier \
  -alias sectionacier -keyalg RSA -keysize 2048 -validity 36500 -dname "CN=Section acier" -noprompt
cat > "$BUILD/Sign.java" <<'JAVA'
import com.android.apksig.ApkSigner;
import java.io.*; import java.security.*; import java.security.cert.X509Certificate; import java.util.*;
public class Sign {
  public static void main(String[] a) throws Exception {
    KeyStore ks = KeyStore.getInstance("PKCS12");
    try (InputStream in = new FileInputStream(a[0])) { ks.load(in, a[1].toCharArray()); }
    PrivateKey k = (PrivateKey) ks.getKey(a[2], a[1].toCharArray());
    X509Certificate c = (X509Certificate) ks.getCertificate(a[2]);
    ApkSigner.SignerConfig sc = new ApkSigner.SignerConfig.Builder("sectionacier", k, Collections.singletonList(c)).build();
    new ApkSigner.Builder(Collections.singletonList(sc)).setInputApk(new File(a[3])).setOutputApk(new File(a[4]))
        .setMinSdkVersion(24).setV1SigningEnabled(false).setV2SigningEnabled(true).build().sign();
  }
}
JAVA
javac -nowarn -cp "$TOOLS/apksig.jar" -d "$BUILD" "$BUILD/Sign.java"
mkdir -p "$(dirname "$OUT")"
java --add-exports java.base/sun.security.x509=ALL-UNNAMED --add-exports java.base/sun.security.pkcs=ALL-UNNAMED --add-exports java.base/sun.security.util=ALL-UNNAMED -cp "$TOOLS/apksig.jar:$BUILD" Sign "$KS" sectionacier sectionacier "$BUILD/aligned.apk" "$OUT"
echo "APK : $(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
