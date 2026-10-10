# Pencil'd — Complete Tri-Layer Screen & Canvas ID Reconciliation

This reference document correlates all 3 ID layers across the Pencil'd design project:
1. **Reference Document Canonical IDs** (Historical snapshot IDs from earlier catalog maps, e.g. `fbe4384a...` / `b9b59458...`)
2. **Current Live Canvas Item IDs** (Active 32-character hexadecimal IDs currently mounted on your Stitch canvas snapshot)
3. **DataStore System Screen Placeholders** (Immutable backend entity keys, e.g. `SCREEN_102`)

---

## Master ID Reconciliation Table

| Screen Title | DataStore System Key | Active Live Canvas Item ID | Reference Doc Canonical ID (DOC_3 / Chat 53) | Status & Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Home Empty State** | `SCREEN_102` | `932801a6d82048379e4c3a8e4670d840` | `fbe4384a12264d05beabb17d381cb56a` / `b9b594589f1f473db2ea29b5f9a49ec7` | Active Root Tab |
| **Source Chooser** | `SCREEN_100` | `1049736e25fa4c9e8ef867cdb0d9ab2d` | `ff3f9dc009634ef184ee1265fe01bbb8` / `106866fbc60e4157a12de509de95d1b5` | Ingestion Hub |
| **Event Review & Edit** | `SCREEN_98` | `7c06357e2b08475fa91e0f6229c810fa` | `f81f5f07d496494d86fb5b4ddadfa74f` / `6da8284156904bf19c27cac65e31a3fa` | Verification Step |
| **Reminder Schedule Editor** | `SCREEN_96` | `e7c60f339a4b4378a4d6f5d98eda5dbf` | `2be50785f7984d278ea209ebb04586ec` / `3fc839ce40034ecdb696951c33dd2e0f` | SMS & Push Rules |
| **Saved Event Detail** | `SCREEN_94` | `853ecdcb193c4a53b39f9a71d80198a1` | `1032e689b29a47939c6c78698052bc04` / `f7c404846bbd4c94a7b370e08df9dd35` | Save Confirmation |
| **Pencil'd Splash Screen** | `SCREEN_92` | `4f1ce304a10747e0b0e8ed29500e8364` | `83c1bbed375c4e64a11e4d6cf118ddcb` / `18a6a8bea14a43139d6ca46c69d62980` | Cinematic Splash |
| **Edit Event** | `SCREEN_89` | `559d3219555a4e1599f4923bcb4d6cc3` | `9d3fb88befbb41e58764a589104c6176` / `8d70f9b4a8744c5da0c5bbab7d39ea71` | Event Form Editor |
| **Agenda** | `SCREEN_87` | `9b6ab90dc9d94e1488b3475d08457ce8` | `f28e0e9083b14d36adb4704f55aee638` / `a693440c83a04507bf73b0143d9d004e` | Timeline Feed |
| **Event Details** | `SCREEN_85` | `83dcb64f58f64f79b355acba1dc8ce44` | `7407fd1d5a964b55953c301c8e917305` / `a6562adcb25246df9845b3e8bfe3863a` | Calendar Inspector |
| **Settings** | `SCREEN_83` | `ca063306bebb4e03b18554b153967164` | `190f858174284706925d97c3896183b4` / `f7edcd0799ff4c5380b269ca349bdda8` | Settings Main Hub |
| **Automatic Review** | `SCREEN_81` | `78226208a4374deca16beab249f99375` | `83b470e1c9204a508956455573bfd841` / `b1d40ba9bbee4b75beebe4fcdf1daf63` | Background Queue |
| **Review Multiple Events** | `SCREEN_79` | `e4767cc6fc054d3e85a762b5a4fb1916` | `cff09c75a5644009a91980039885eb50` / `f1aa01177a3c48f0b2f1443f67947742` | Batch Multi-Triage |
| **User Profile** | `SCREEN_77` | `6be19764ad2b459aa704ae218e7ab16e` | `e1579dc2f4b44b999727d1d14f8aea4a` / `42b6997581604c65bb98da78c8142feb` | Account & Tier |
| **Screenshot Triage** | `SCREEN_75` | `74796ecf212b41d88955d67dad0b9f72` | `06b14b0141ea45f6b17c298dbdb72b06` / `b289f659ceee4e4ba1535e23eecb36b8` | Radar Ingestion |
| **PDF & File Review** | `SCREEN_57` | `317a0ef98f6548c897541af72b794b17` | `055befddc2214768aca60f2ef44fc33f` / `4d007694af044b58a12ed7bc4af7ea02` | v2 Carousel View |
| **Extraction Details** | `SCREEN_71` | `38326d4b98ae4f438e38e6e83ff18de2` | `066c3f7d70c542d5a59daa1f2646e1ee` / `16dd3424b6c84bb5a5f637d1ee032294` | OCR Inspector |
| **Scan Processing Progress** | `SCREEN_69` | `ea0123e80508447bbd1a738fae059598` | `7518b065195d472b95d1de6c531f5305` / `9e7bbc90ad704b259c9e45288f82e22b` | Neural HUD |
| **History & Archive** | `SCREEN_67` | `9ef38479ff5145dfa3bfc3bdd2eb3baa` | `88b16e4687d644a995a3ec0c3cf854ac` / `5283c1cdc59f42e996e591a882c7e985` | Past Captures |
| **Batch Scan Queue** | `SCREEN_59` | `789e75a604724291a8eb12baae92e10a` | `662f5ef79f254460b641f03be61c00b1` / `2a635408bafc4ed5865b044a7875fca2` | v2 Queue Manager |
| **Premium Paywall** | `SCREEN_63` | `f64e6a9372b6491ca41da99d1357c1c3` | `eab25e1f62d84bd2beb2c91eda10f328` / `ed8085a553da4797a6db821784ce6d0d` | Lifetime Tier Added |
| **Plus Paywall** | `SCREEN_61` | `700f9a8a15414965aab2f0d13fe96138` | `8e693fe0c6134c9ebdb8044b362893a5` / `c99d526574b14678ba53547906f6101e` | Lifetime Tier Added |
| **Calendar Permission Denied** | `SCREEN_55` | `eea5b081a8874939b2ce76bf1ebd7aea` | `420f4607817a4ab4bf423275d8d520af` / `c22e615e3fff46058bdffef860473f2b` | Deep link CTA |
| **Notification Permission Denied**| `SCREEN_53` | `f1575a289e894091b1b70f3f387482b8` | `6c55f02e2a164cee9d3d1ee03cd6e54a` / `5f65350a6bda4ceeb2cd795f41691e84` | System Settings link |
| **No Dates Found** | `SCREEN_51` | `b5c0e96fc4314efc8870ddd2b41f7054` | `b11a3800c14646748573e492eabbdbd2` / `e99d207014af45eb92f5627a1a4fc59e` | OCR Fallback |
| **Smart Suggestions** | `SCREEN_49` | `87013e6e43c34a4cb8fdbc7ade276f90` | `7b9ac49f4cb8429f89fcdbe7a385231b` / `4b3241d0c6294807a2acc080f59fbf0e` | AI Parameters |
| **Default Calendar** | `SCREEN_47` | `edd5a23af4884ce8a7fcf081e7880a1b` | `51e330d6e9fc4fefb81e140cd7f29838` / `5554b91b29ff42f9b944397f86f20856` | Apple/Google targets |
| **Source Preferences** | `SCREEN_45` | `bd481b10597e4daaaf7288a08ea4873e` | `70672a6c87cb4dfda8c326199980ab26` / `47a62b99de0d4ef2a1ac90756c08b1da` | Formats & OCR rules |
| **Reminder Presets** | `SCREEN_43` | `b33da19e60ec4ce3a341a1468230b94b` | `743a9b3e34ca4e198f168ac427bb3dcc` / `12af69dd798f4ebab1c88d2b82833f01` | Default Cadences |
| **Notification Preferences** | `SCREEN_41` | `baf08a7233184ff392a16366f8ff166f` | `73bc7e2b84d64b6fb5b06b11f16c8821` / `08b3cf6a4166442cb9c183b2ea0c647c` | Push & SMS Channels |
| **Automatic Capture** | `SCREEN_39` | `fa2ba0b3ab764d8dbfdfbcc59b0ad0a2` | `48e1e7cc3474407184365c4c4b876a0e` / `39cb36095b0b4004bfcb7427b7b71ab3` | Background Radar |
| **Privacy & Processing** | `SCREEN_37` | `a7c768ec2bc342e3bafd2a241656ab25` | `386887cd99e644d58df555eb784e03f1` / `f9d410b773ed4063bf5bdea1ca1603d2` | On-Device Neural Engine |
| **Manage Subscription** | `SCREEN_35` | `56707f5d711c4f479689f3592b0a9dfa` | `3ae5f792048947cb95c7834693829a1f` / `1db89655bfdd493dad9c756b5f6f8389` | Tier Management |
| **App Preferences** | `SCREEN_33` | `72a2b6cb15c549a69355b1bc0d9e03f0` | `c77e5205b8504b858b783cc58241bac7` / `4a5c6b75b9834ecbb0a1f1959fe14f38` | Localizations & Clock |
| **Help & Support** | `SCREEN_31` | `e7675668d2ac401eb9489245152109ba` | `603036ba090a43fa89c09f56742c3c2c` / `98e6b90284dc42c7a63bd45b97130d3c` | Tutorials & FAQs |
| **Verify Email Address** | `SCREEN_28` | `ab0731da53a7464f9e617c5b1066d4f3` | `b64f0f2b53f54ecb94ddd3c19a654485` / `a1ca8221b42d4cabbbfc391386ee8dae` | Email Entry |
| **Enter Phone SMS Code** | `SCREEN_26` | `fe0c13c225a94ac8be6e25237f2f47c4` | `8312446ef9704f9190521c251b4d3edc` / `5f61ef6e8f1945e69b1b68a2b951919f` | 6-Digit PIN |
| **Verify Phone Number** | `SCREEN_24` | `f755764bf9e54b62ad4c98fb96e012a6` | `b668f96e38cc4d218448aa79ea087842` / `d0a5c0b571a5465fb0af5f5ab9b918c4` | Phone Entry |
| **Verification Complete** | `SCREEN_22` | `99e01325f33041439b7fd2ffad9551f5` | `fd8816a0703040a7b4329f1dce6a12fc` / `fbcb88a478634159b763552ecfe6d591` | Success State |
| **Check Email Inbox** | `SCREEN_20` | `62de2309f1404c32bcc09ee667b916f4` | `cb904a46e71c470e9dd4da1548a47c09` / `c2b56e6800d5470ca7de29d832628a1e` | Magic Link Reader |
| **Marketing Copy & Email Template** | `SCREEN_16` | `7325529f27e84298ac4b54b4d242423f` | `b8f7125d147144598bd55ab3e51620b4` / `24b140c3a3c840978a5e89fcc520531c` | Desktop Promotional Sheet |

---

## Marketing & App Store Showcase Assets Reconciliation

| Asset | System Key | Active Live Canvas Item ID | Reference Doc ID (Chat 53 / DOC_2) |
| :--- | :--- | :--- | :--- |
| **Social Media Post Card (1:1)** | `IMAGE_19` | `5a63201f26b7498998aba17cee69637a` | `80bdedbaa7a34cf282e17f51a0132772` / `IMAGE_18` |
| **Email Newsletter Header (16:9)** | `IMAGE_18` | `360e85654d80461693f9c1f1a1915146` | `2f713e4f73624c39bcc97e976a1ad9cb` / `IMAGE_17` |
| **Display Banner Ad (16:9)** | `IMAGE_17` | `ded8f82a7dc040b49175e5b6fd01e85e` | `0165d8a2c8864bfe83e89d8264d74af8` / `IMAGE_16` |
| **iPhone Slide 1 (Capture Engine)** | `IMAGE_13` | `6c7472a452ad4437a5d7eaf5dc109422` | `3400bb8ad478457e981b75e018c44c24` / `IMAGE_12` |
| **iPhone Slide 2 (AI Verification)** | `IMAGE_12` | `a4ff9d6a17474cbba325c7c57a85f940` | `d840ca7bfb05419fb6790772e1072545` / `IMAGE_10` |
| **iPhone Slide 3 (Multi-Page Syllabi)** | `IMAGE_11` | `08ff43bd9f3b48c9afde3d19fb4f9f71` | `2ac5429a0f5342a6806a5730b57f8ea5` / `IMAGE_11` |
| **iPhone Slide 4 (Reminders & SMS)** | `IMAGE_10` | `de47987ee59c45beadfa48d0beb9f353` | `0306ebe6f8204f8ab97560d744d541c7` / `IMAGE_8` |
| **iPhone Slide 5 (Calendar Sync)** | `IMAGE_9` | `b72adff86e72420a9238a63411cbc90b` | `afd3e579d4a94d2081b70e4167ab9023` / `IMAGE_9` |
| **iPad Slide 1 (Canvas Scanning)** | `IMAGE_8` | `a31344e4c4704fc6b0e62fcb15177ab8` | `ea4af6a7517748d2a263ac5e3a8fd096` / `IMAGE_7` |
| **iPad Slide 2 (Two-Column Verification)** | `IMAGE_7` | `edcbad5185614003af1778e9fa91b9cb` | `004834554d42438f8cb8291a5488746b` / `IMAGE_6` |
| **iPad Slide 3 (Batch Syllabus Triage)** | `IMAGE_6` | `5868377abe7f4c649adc7e2e2803dd1f` | `1a5a00624e0049a788bae38cf3b641b1` / `IMAGE_5` |
| **iPad Slide 4 (Granular Alerts & Privacy)** | `IMAGE_5` | `f1956293f9fd4e29bac47aa0f85a9b67` | `85c5affb59b747ff85c6f267f7a61dec` / `IMAGE_3` |
| **iPad Slide 5 (High-Density Agenda Sync)** | `IMAGE_4` | `505617df13e04aacace67f2ec7c2d5a3` | `f87f48c4cb7349a88100d2a5033b7377` / `IMAGE_4` |
