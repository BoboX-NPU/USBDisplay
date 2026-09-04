# Device Corner Reference Profiles

The checked-in table in `DisplayCornerProfile.swift` was extracted on 2026-09-05 from Apple's locally installed CoreSimulator device profiles under `/Library/Developer/CoreSimulator/Profiles/DeviceTypes`. The app does not read these files or call simulator/private APIs at runtime.

These are simulator display-reference measurements, not a claim that AVFoundation reports physical screen corners. Only exact `modelIdentifier` / public capture `modelID` matches are accepted. Regional hardware variants absent from the source are intentionally not guessed. Generic identifiers such as `iPhone` and user-editable device names do not select a profile.

Calibration uses the integrated primary display's four equal `cornerRadiusUL/UR/LL/LR` values in logical points. The normalized radius is `cornerRadiusUL / (min(width, height) / scale)`. This agrees with `DeviceCornerRadius` where present. For example, iPhone 16 Pro is 62 / (1206 / 3) = 15.4229%; iPad Pro 13-inch (M4) is 30 / (2064 / 2) = 2.9070%. CALayer continuous corners render this reference geometry; actual device appearance still requires physical validation.

To refresh, inspect `Contents/Resources/capabilities.plist` in each listed `.simdevicetype`, require an exact model identifier and four explicitly equal radii, and compare source hashes below. Do not add aliases or missing radii by assumption. The existing manual per-device override remains available and takes precedence.

| Model ID | Device | Radius (pt) | Short side (pt) | Source bundle | SHA-256 of capabilities.plist |
| --- | --- | ---: | ---: | --- | --- |
| iPad11,1 | iPad mini (5th generation) | 0 | 768 | iPad mini (5th generation).simdevicetype | `7387b13f13e2044b8d77f442ae22774dcfc661d3d2c3056c173d1fc81bb94a3b` |
| iPad11,3 | iPad Air (3rd generation) | 18 | 834 | iPad Air (3rd generation).simdevicetype | `09083195a26bd525a1e7bac9a4d9ca340a3aa192fbff4f8ed71aff163979e008` |
| iPad11,7 | iPad (8th generation) | 0 | 810 | iPad (8th generation).simdevicetype | `8fddb99fb3b7834e85d9c5c334f91cf1456f13c294b175e18aae1b63a9e399ed` |
| iPad12,2 | iPad | 0 | 810 | iPad (9th generation).simdevicetype | `31e7b00de0b8a95a2ad8f3487fc21f531ae940d7fe0f6a056227488e80d1a39a` |
| iPad13,10 | iPad Pro (12.9-inch) (5th generation) | 18 | 1024 | iPad Pro (12.9-inch) (5th generation).simdevicetype | `3f4b0daa23a704b492757c1cf3f5a23e40e6d001b20b1c6dcda3565626df41ac` |
| iPad13,17 | iPad Air (5th generation) | 18 | 820 | iPad Air (5th generation).simdevicetype | `4ceec6797499f1461b7e2314220da323c3ea53cd6bd048b8529d2b1abf054143` |
| iPad13,18 | iPad (10th generation) | 25 | 820 | iPad (10th generation).simdevicetype | `8fd866f8055ed7775b8c21cc222f6c5aa3dd6440fdbeb0031bb950f838ee7bb0` |
| iPad13,2 | iPad Air (4th generation) | 18 | 820 | iPad Air (4th generation).simdevicetype | `06a687edc291919f42a40ff5037fd11064308de338285e338caae1bc8c6b5098` |
| iPad13,5 | iPad Pro (11-inch) (3rd generation) | 18 | 834 | iPad Pro (11-inch) (3rd generation).simdevicetype | `d214cfefdb177ec42dc6f0f4d12b337ec4897b0b490f33af3f91d0417ea9d18c` |
| iPad14,1 | iPad mini | 21.5 | 744 | iPad mini (6th generation).simdevicetype | `1d700661fbf83cb8f0d0bdd4661493f39ac0a5ee13a229b9f0f664303ebf2d8b` |
| iPad14,11 | iPad Air 13-inch (M2) | 18 | 1024 | iPad Air 13-inch (M2).simdevicetype | `0df065c95a2508718cbc38d2a4e5c698ee97f3d564d39079229360ef9b5ec4e5` |
| iPad14,3 | iPad Pro (11-inch) (4th generation) | 18 | 834 | iPad Pro (11-inch) (4th generation).simdevicetype | `31c2dc6cfb341c379199d461f883f1bb7abfb913b46a2532be258b96c45ac22d` |
| iPad14,4 | iPad Pro (11-inch) (4th generation) | 18 | 834 | iPad Pro (11-inch) (4th generation) (16GB).simdevicetype | `22af62566a89c1bbe6e257455313cf8edcc9814e937d2eb9e7b5117ea0a5b150` |
| iPad14,5 | iPad Pro (12.9-inch) (6th generation) | 18 | 1024 | iPad Pro (12.9-inch) (6th generation).simdevicetype | `39d633860b7cbff648e815dfd595297e7b55ffe3e677a16ba0edbc0a39aa9b54` |
| iPad14,9 | iPad Air 11-inch (M2) | 18 | 820 | iPad Air 11-inch (M2).simdevicetype | `7b5a697f0f3f926a68ce302bf8fe41654c8cac41a668c8e5c215c05885180612` |
| iPad15,3 | iPad Air 11-inch (M3) | 18 | 820 | iPad Air 11-inch (M3).simdevicetype | `a68aaa8a63d0fc8fec7dedb33baa11cf11068f4e3799f962a3846aba6bb3b87a` |
| iPad15,5 | iPad Air 13-inch (M3) | 18 | 1024 | iPad Air 13-inch (M3).simdevicetype | `bfceec91b1065fd0af90f53899f1784a80515c087aa263c01a0b117ce9fe1ca2` |
| iPad15,7 | iPad (A16) | 25 | 820 | iPad (A16).simdevicetype | `b8f9559ced3fba64e908b5a06a5a5cb33bf7771ece3e211e6072ba37bfc2ea91` |
| iPad16,11 | iPad Air 13-inch (M4) | 18 | 1024 | iPad Air 13-inch (M4).simdevicetype | `cc087ee24531a593a82d6a53173421360434888efdc0add6eb413511d148c159` |
| iPad16,2 | iPad mini (A17 Pro) | 21.5 | 744 | iPad mini (A17 Pro).simdevicetype | `bf9f68f7b7d70879d6d35b60de1b931a092d740f5148e3e88501331c6f1a37df` |
| iPad16,4 | iPad Pro 11-inch (M4) | 30 | 834 | iPad Pro 11-inch (M4).simdevicetype | `ea6c2f0958a295e348b4fd49fa0dbf2b56cc84a61c25b71cac7e66840d36c626` |
| iPad16,6 | iPad Pro 13-inch (M4) | 30 | 1032 | iPad Pro 13-inch (M4).simdevicetype | `87af9ba70f2cc92fd1d14dfa37bf445579eac1722d3a5e04ffa963ece56a24da` |
| iPad16,9 | iPad Air 11-inch (M4) | 18 | 820 | iPad Air 11-inch (M4).simdevicetype | `254aba874d806e417120a02c49b4a7cb844455ae6e7dcdb91ba2071aa2eb6bd2` |
| iPad17,2 | iPad Pro 11-inch (M5) | 30 | 834 | iPad Pro 11-inch (M5).simdevicetype | `677d0e5bc15a1376db82cb96510b82bc392765c6018421b4b41a5bb722b139e8` |
| iPad17,4 | iPad Pro 13-inch (M5) | 30 | 1032 | iPad Pro 13-inch (M5).simdevicetype | `d580723780d7c5fff2ddd37730f2541ef5d9c251dda0ad152866221f434fba5e` |
| iPad5,1 | iPad mini 4 | 0 | 768 | iPad mini 4.simdevicetype | `c73364611774be9f6c994abd87790ee1bdce582454e13c53eae3a491c43f5b92` |
| iPad5,4 | iPad Air 2 | 0 | 768 | iPad Air 2.simdevicetype | `353309b8a9b5e514522edfe8a670170ee53dd31c53881a28b2c9a6763d2200f9` |
| iPad6,12 | iPad (5th generation) | 0 | 768 | iPad (5th generation).simdevicetype | `636fcb2d9f159d86e85a647507b918c1051f8a6b29a4ca67a4b396cf67dc4f68` |
| iPad6,4 | iPad Pro (9.7-inch) | 0 | 768 | iPad Pro (9.7-inch).simdevicetype | `1e7fa67fe178dd097ab621d94f1c62425a0fbb5222f6e2de1220e8f001e87628` |
| iPad6,8 | iPad Pro | 0 | 1024 | iPad Pro (12.9-inch) (1st generation).simdevicetype | `b97caac930a56921da247253a934b6157915283ded55a6020b67842d74823bd0` |
| iPad7,1 | iPad Pro (12.9-inch) (2nd generation) | 0 | 1024 | iPad Pro (12.9-inch) (2nd generation).simdevicetype | `6d689bc5412d0332f9fb8f4d6051b641f15d2de91ebca1c9c1ae9252df2d4378` |
| iPad7,12 | iPad (7th generation) | 0 | 810 | iPad (7th generation).simdevicetype | `cb0fb660ea3fbe6f9aeab80cef9534465ba5dbed8a361e1a20c0548cbf2447ed` |
| iPad7,3 | iPad Pro (10.5-inch) | 0 | 834 | iPad Pro (10.5-inch).simdevicetype | `a63565f74d7b2c34deabe9ad04bb0ed1342ea4913e959aa440831d8aab5c04bb` |
| iPad7,6 | iPad (6th generation) | 0 | 768 | iPad (6th generation).simdevicetype | `b0d50788c0f799d10a353e4ae1fddcb9aeeb3cf599b7bb016ab14d91283865de` |
| iPad8,1 | iPad Pro (11-inch) (1st generation) | 18 | 834 | iPad Pro (11-inch) (1st generation).simdevicetype | `7088257081d367892b30448005a7a4f4a881a65df623e4d655547457683299e2` |
| iPad8,12 | iPad Pro (12.9-inch) (4th generation) | 18 | 1024 | iPad Pro (12.9-inch) (4th generation).simdevicetype | `95658fe1b13de12b70457a906d8f6adb3708995b5dacc629c54f9e6203bf9ca6` |
| iPad8,5 | iPad Pro (12.9-inch) (3rd generation) | 18 | 1024 | iPad Pro (12.9-inch) (3rd generation).simdevicetype | `3f62440e48979657ba445cee95fa4936eb2bcdccba7556d0869caebe36acc28a` |
| iPad8,9 | iPad Pro (11-inch) (2nd generation) | 18 | 834 | iPad Pro (11-inch) (2nd generation).simdevicetype | `22704a435e26b74a3234f009f8889a90c5cdf080591fed30f66960fa384401f3` |
| iPhone10,4 | iPhone 8 | 0 | 375 | iPhone 8.simdevicetype | `cc139fac9b21011248671c6cd4c7bba33653308c13f6a2f34025713cc2c3b3f4` |
| iPhone10,5 | iPhone 8 Plus | 0 | 414 | iPhone 8 Plus.simdevicetype | `8eec0bc058fa72f3487cb19fa487a231dc57536b5d70c5613ae911684e34689c` |
| iPhone10,6 | iPhone X | 39 | 375 | iPhone X.simdevicetype | `ce9b8ce53cfef110197d1dd6c2b2455049cda0d32c315f03b2ac1385768d6995` |
| iPhone11,2 | iPhone XS | 39 | 375 | iPhone Xs.simdevicetype | `0e1ae290053fe9f9bab41c6626fe76472b60a55886e23942beab64a78c2dfbf9` |
| iPhone11,4 | iPhone XS Max | 39 | 414 | iPhone Xs Max.simdevicetype | `9aa342d3e7559204336af385de43c500098154f3e24cfcaa4081cbfc6bd06bf2` |
| iPhone11,8 | iPhone XR | 41.5 | 414 | iPhone Xʀ.simdevicetype | `b669d19c3ab40ca61280b061097c0c9243d31adf1fecc0ff59deb291e162466b` |
| iPhone12,1 | iPhone 11 | 41.5 | 414 | iPhone 11.simdevicetype | `74a8a83e657fff8e0196aba7f0ad71f1332c89cd66cfe54d7adfecdac76d6aab` |
| iPhone12,3 | iPhone 11 Pro | 39 | 375 | iPhone 11 Pro.simdevicetype | `f32b9b1549c8eff8e1686ccd0c4d51b912522fda747d9be5bb5e37e8e3a2a88e` |
| iPhone12,5 | iPhone 11 Pro Max | 39 | 414 | iPhone 11 Pro Max.simdevicetype | `8b9114f11d1145477fa84fd84820d0b88adfd7ef83d5c88b534d904be5161994` |
| iPhone12,8 | iPhone SE | 0 | 375 | iPhone SE (2nd generation).simdevicetype | `88dfd0453b1db9fb065bdad514bde9dd28d2cbc0dd58eeefae4fe0d3b6bc4f34` |
| iPhone13,1 | iPhone 12 mini | 44 | 360 | iPhone 12 mini.simdevicetype | `41d9c21c47006586398b96b8b98f7e2ad853f35e117a0673e818f4bd1abc3a57` |
| iPhone13,2 | iPhone 12 | 47 | 390 | iPhone 12.simdevicetype | `7dde21915a2d979ba9a7d989e5b1071879b859749369289593848d5aab06c50a` |
| iPhone13,3 | iPhone 12 Pro | 47 | 390 | iPhone 12 Pro.simdevicetype | `01700b4e4ca0ce891821b66e6f90a1b7053d708cd2d9f7589672ac915c3c6d00` |
| iPhone13,4 | iPhone 12 Pro Max | 53 | 428 | iPhone 12 Pro Max.simdevicetype | `2971a17f9af59f4302fdf1cbdced3d6323d6cb924e6d7dafbdad51d5203ed065` |
| iPhone14,2 | iPhone 13 Pro | 47.3333 | 390 | iPhone 13 Pro.simdevicetype | `d0a20096f7a7efad64491bfa4c16c07fc79bb9b39212569697d73163314525ba` |
| iPhone14,3 | iPhone 13 Pro Max | 53.3333 | 428 | iPhone 13 Pro Max.simdevicetype | `8c6d490999750cd6f387ea018a6e7fb46ce1924395ec8ad5673e9a24101da1b8` |
| iPhone14,4 | iPhone 13 mini | 44 | 360 | iPhone 13 mini.simdevicetype | `adbdb0a525688e2ef8aebf88adb246c8725e77fb9a6572bd2c0db86e7fde68d9` |
| iPhone14,5 | iPhone 13 | 47.3333 | 390 | iPhone 13.simdevicetype | `db8dd292eb722b681d80ea3609c3191169f52c1f7ad86605931d0b65cad1e902` |
| iPhone14,6 | iPhone SE (3rd generation) | 0 | 375 | iPhone SE (3rd generation).simdevicetype | `b0ede511801c484862c46eb0e6183aead98d6f8c1a39cd48823fdff00dd24960` |
| iPhone14,7 | iPhone 14 | 47.3333 | 390 | iPhone 14.simdevicetype | `01793dd9b4d1abed2358a2893ec31c9b7fa05881a15eb540c69cab999e4c0687` |
| iPhone14,8 | iPhone 14 Plus | 53.3333 | 428 | iPhone 14 Plus.simdevicetype | `512e6960279185a35ecbe80f602a39cd77f98303f331b8bcc068ec5d8aff98eb` |
| iPhone15,2 | iPhone 14 Pro | 55 | 393 | iPhone 14 Pro.simdevicetype | `b6d2f52d00e0c0758467c1239affa30adbf425bf5ce93e159807636736cb82ae` |
| iPhone15,3 | iPhone 14 Pro Max | 55 | 430 | iPhone 14 Pro Max.simdevicetype | `eef2c2f38e212851c9f8dc1b283e893bcc955f767dc5e757879b4b481772aaa5` |
| iPhone15,4 | iPhone 15 | 55 | 393 | iPhone 15.simdevicetype | `da864de8edc16f0ffa51abc33769ccda1aa6afdc870e762b2046805053604c67` |
| iPhone15,5 | iPhone 15 Plus | 55 | 430 | iPhone 15 Plus.simdevicetype | `8c1be0ef0e828a8639d085cbe26b853c371ed82c305c1994deba1b945c9847f6` |
| iPhone16,1 | iPhone 15 Pro | 55 | 393 | iPhone 15 Pro.simdevicetype | `2ad2ba1fe52acef891f5a37d4da7ef51a66a2e815b7e3591f98575839cea1af5` |
| iPhone16,2 | iPhone 15 Pro Max | 55 | 430 | iPhone 15 Pro Max.simdevicetype | `743749bdd84416ead561fc222bc2951ae4e93239fb0a6608e4aa3ae70c3a08a2` |
| iPhone17,1 | iPhone 16 Pro | 62 | 402 | iPhone 16 Pro.simdevicetype | `48db6ea44c0d3bad40561ee5f62d98afd97ab306ebbb85a0346a2f376987122e` |
| iPhone17,2 | iPhone 16 Pro Max | 62 | 440 | iPhone 16 Pro Max.simdevicetype | `3b007d11cd54f014abc778aecd3eba4ad1fd7f3940c6786f643266473505b279` |
| iPhone17,3 | iPhone 16 | 55 | 393 | iPhone 16.simdevicetype | `f02c4d7e0628ed0d8de0495b2106b8c592f2b7698a895efbf44881626f08caec` |
| iPhone17,4 | iPhone 16 Plus | 55 | 430 | iPhone 16 Plus.simdevicetype | `31e8c8d0d101ed05b64fe2dd2753a9a60a2dad587463ca17d0d4a95dc9032029` |
| iPhone17,5 | iPhone 16e | 47.3333 | 390 | iPhone 16e.simdevicetype | `2116f956eb582a67e28bcac98d91301050d86f4f2d4b2909782566cc381b7c99` |
| iPhone18,1 | iPhone 17 Pro | 62 | 402 | iPhone 17 Pro.simdevicetype | `0a1777c9a461ecc20f6cd799b21f9d872a3691f0e31ec69ee0460c9053737f4e` |
| iPhone18,2 | iPhone 17 Pro Max | 62 | 440 | iPhone 17 Pro Max.simdevicetype | `361987ab7139dc05d3c34d9d80bc649791abe8371b96106da437c760687f4860` |
| iPhone18,3 | iPhone 17 | 62 | 402 | iPhone 17.simdevicetype | `5b14e92da16c2d14595b5cf8700935cf6f984917689eda8d7c173416da052e57` |
| iPhone18,4 | iPhone Air | 62 | 420 | iPhone Air.simdevicetype | `ed74b9584675b33373ccac32b2e38fdb7dc8ced1f3db94e2800d7d4899304d61` |
| iPhone18,5 | iPhone 17e | 47.3333 | 390 | iPhone 17e.simdevicetype | `3878a048ae271f2fdbabfe75618803ec8031598daaa3c5f8ccb61c48e6363a89` |
| iPhone8,1 | iPhone 6s | 0 | 375 | iPhone 6s.simdevicetype | `4d19d971c96ca4323278f40e8c66124421a5d1493c1b865756570dba09fab262` |
| iPhone8,2 | iPhone 6s Plus | 0 | 414 | iPhone 6s Plus.simdevicetype | `3fd9a46dc8a7444064b10235e72b68b597dc21901bfda157f34cdd2b5d638990` |
| iPhone8,4 | iPhone SE | 0 | 320 | iPhone SE (1st generation).simdevicetype | `29075434e6dc89256195d6c5dfbb26eff58ef24be94aec074eae8585c7f33884` |
| iPhone9,1 | iPhone 7 | 0 | 375 | iPhone 7.simdevicetype | `ed84103dd2fbd94b95a98054247e7585159916ff3481dc186624e9976fbee665` |
| iPhone9,2 | iPhone 7 Plus | 0 | 414 | iPhone 7 Plus.simdevicetype | `3ebd95012ae8b61fbdb91c1a52ac703817454988ba96a47a3f9277a5d2f68edc` |
