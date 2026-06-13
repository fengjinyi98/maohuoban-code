CREATE TABLE IF NOT EXISTS legal_documents (
    kind text PRIMARY KEY,
    title text NOT NULL,
    version text NOT NULL,
    effective_date date NOT NULL,
    published_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    is_published boolean NOT NULL DEFAULT true,
    html text NOT NULL,
    CONSTRAINT legal_documents_kind_check CHECK (kind IN ('user_agreement', 'privacy_policy'))
);

CREATE INDEX IF NOT EXISTS idx_legal_documents_published
    ON legal_documents(kind, is_published);

INSERT INTO legal_documents (
    kind,
    title,
    version,
    effective_date,
    published_at,
    updated_at,
    is_published,
    html
) VALUES (
    'user_agreement',
    '用户服务协议',
    '2026-06-13',
    DATE '2026-06-13',
    TIMESTAMPTZ '2026-06-13T00:00:00Z',
    TIMESTAMPTZ '2026-06-13T00:00:00Z',
    true,
    $user_agreement$
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <style>
    :root {
      color-scheme: light;
      --bg: #f7faff;
      --card: rgba(255, 255, 255, 0.84);
      --label: #1f2937;
      --secondary: #4b5563;
      --tertiary: #7c8798;
      --primary: #4f8cff;
      --primary-bg: #edf5ff;
      --separator: rgba(31, 41, 55, 0.09);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px 18px 40px;
      background: var(--bg);
      color: var(--label);
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif;
      line-height: 1.75;
      -webkit-font-smoothing: antialiased;
    }
    main {
      max-width: 760px;
      margin: 0 auto;
      background: var(--card);
      border: 0.5px solid var(--separator);
      border-radius: 18px;
      padding: 22px 18px;
      box-shadow: 0 16px 38px rgba(79, 140, 255, 0.08);
    }
    h1 { margin: 0 0 8px; font-size: 24px; line-height: 1.25; }
    .meta { display: flex; flex-wrap: wrap; gap: 8px 14px; color: var(--tertiary); font-size: 12px; margin-bottom: 18px; }
    .intro { font-weight: 650; color: var(--label); }
    section { padding-top: 12px; margin-top: 12px; border-top: 0.5px solid var(--separator); }
    h2 { margin: 0 0 8px; font-size: 17px; line-height: 1.35; }
    p { margin: 0 0 10px; color: var(--secondary); font-size: 15px; }
    ul { margin: 0; padding-left: 20px; color: var(--secondary); font-size: 15px; }
    .highlight {
      margin: 14px 0;
      padding: 12px 13px;
      background: var(--primary-bg);
      border: 0.5px solid rgba(79, 140, 255, 0.16);
      border-radius: 12px;
      color: #2563c9;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <main>
    <h1>用户服务协议</h1>
    <div class="meta">
      <span>版本发布日期：2026年06月13日</span>
      <span>最新生效日期：2026年06月13日</span>
    </div>
    <p class="intro">欢迎您使用毛伙伴（Maohuoban）平台服务！本用户服务协议是由您与毛伙伴服务运营商之间就账号注册、服务使用及各项相关权益等事宜所订立的契约。请您在使用前认真阅读并充分理解各条款内容。</p>

    <section>
      <h2>一、账号注册与使用规范</h2>
      <p>1. 注册凭证与实名关联：本平台支持通过中国大陆有效手机号码一键获取验证码的方式进行注册。用户完成短信验证登录后，即完成账号实名关联。</p>
      <p>2. 档案建立与管理：毛伙伴是一个以宠物为主体的协同记录平台。用户有权为自己合法饲养或托管的宠物建立独立主页、健康档案和成长时间线。</p>
      <p>3. 账号安全责任：用户应当妥善保管手机账号的验证信息，任何通过用户手机号验证完成的登录、建档、预定等操作行为，均视为用户本人的真实意志表达。</p>
    </section>

    <section>
      <h2>二、宠物主体协同服务规则</h2>
      <p>1. 照护记录真实性：用户可在平台记录宠物食欲、精神、排泄及日常体重等生命数据，以便于多家庭成员共享或就医协同。用户需承诺上传的宠物数据属于客观真实记录。</p>
      <p>2. 同城就医与预约：当用户使用平台提供的同城医院在线挂号、美容寄养等预定功能时，应遵守商家的预约规则和取消时限。</p>
      <div class="highlight">重要提示：关于“活体交易担保保障”模块，平台仅作为信息服务与技术存管协同工具。所有押金与款项均直接进入持牌金融存管机构进行冻结。</div>
    </section>

    <section>
      <h2>三、用户行为与内容规范</h2>
      <p>用户在使用毛伙伴服务过程中，发布的内容必须遵守国家有关法律法规，严禁发布以下内容：</p>
      <ul>
        <li>侵害任何第三方名誉权、隐私权、肖像权或著作权等合法权益的言论或图片；</li>
        <li>违背社会公德，展示或宣扬虐待动物、遗弃动物或非法宠物繁育交易的信息；</li>
        <li>含有虚假虚构的宠物伤病求助，或带有诈骗倾向的筹款众筹链接。</li>
      </ul>
    </section>

    <section>
      <h2>四、平台免责声明</h2>
      <p>1. 健康及记录数据免责：平台提供的日常照护与疫苗驱虫提醒属于非诊疗性质的日常关爱辅助工具，不得替代专业执业兽医师的临床诊断。</p>
      <p>2. 第三方保险协同免责：平台直连的保险理赔协同接口仅作为便捷信息传输通道。保险承保、费率计算、理赔核定等业务由保险公司独立负责。</p>
    </section>
  </main>
</body>
</html>
$user_agreement$
), (
    'privacy_policy',
    '用户隐私政策',
    '2026-06-13',
    DATE '2026-06-13',
    TIMESTAMPTZ '2026-06-13T00:00:00Z',
    TIMESTAMPTZ '2026-06-13T00:00:00Z',
    true,
    $privacy_policy$
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <style>
    :root {
      color-scheme: light;
      --bg: #f7faff;
      --card: rgba(255, 255, 255, 0.84);
      --label: #1f2937;
      --secondary: #4b5563;
      --tertiary: #7c8798;
      --primary: #4f8cff;
      --primary-bg: #edf5ff;
      --separator: rgba(31, 41, 55, 0.09);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px 18px 40px;
      background: var(--bg);
      color: var(--label);
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif;
      line-height: 1.75;
      -webkit-font-smoothing: antialiased;
    }
    main {
      max-width: 760px;
      margin: 0 auto;
      background: var(--card);
      border: 0.5px solid var(--separator);
      border-radius: 18px;
      padding: 22px 18px;
      box-shadow: 0 16px 38px rgba(79, 140, 255, 0.08);
    }
    h1 { margin: 0 0 8px; font-size: 24px; line-height: 1.25; }
    .meta { display: flex; flex-wrap: wrap; gap: 8px 14px; color: var(--tertiary); font-size: 12px; margin-bottom: 18px; }
    .intro { font-weight: 650; color: var(--label); }
    section { padding-top: 12px; margin-top: 12px; border-top: 0.5px solid var(--separator); }
    h2 { margin: 0 0 8px; font-size: 17px; line-height: 1.35; }
    p { margin: 0 0 10px; color: var(--secondary); font-size: 15px; }
    .highlight {
      margin: 14px 0;
      padding: 12px 13px;
      background: var(--primary-bg);
      border: 0.5px solid rgba(79, 140, 255, 0.16);
      border-radius: 12px;
      color: #2563c9;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <main>
    <h1>用户隐私政策</h1>
    <div class="meta">
      <span>版本发布日期：2026年06月13日</span>
      <span>最新生效日期：2026年06月13日</span>
    </div>
    <p class="intro">毛伙伴致力于保护宠物主人和宠物健康相关个人隐私。在您使用日常记录、健康诊断协作、同城预约及保险理赔协同等服务时，我们将按照本隐私政策收集、使用和共享您的个人与宠物隐私信息。</p>

    <section>
      <h2>一、我们如何收集和使用信息</h2>
      <p>1. 基础注册与登录信息：在您注册或登录毛伙伴时，我们会收集您的手机号码，以此向您发送短信验证码。</p>
      <p>2. 宠物基本与健康档案数据：为确保宠物主页及时间线功能正常运作，您在创建宠物档案时需要上传或录入宠物照片、昵称、品种、性别、生日、是否绝育等信息。</p>
      <p>3. 位置与同城服务信息：当您探索同城伙伴、附近认证猫舍犬舍或宠物医院时，我们会在获得授权后收集地理位置，该信息仅用于本地服务测距。</p>
    </section>

    <section>
      <h2>二、数据的共享、披露与协同规范</h2>
      <p>我们严格遵守最小必要共享原则，仅在预约就诊、活体交易履约校验、保险理赔协作等明确定义的协同场景下共享必要数据。</p>
      <p>预约就诊协同时，我们会将宠物头像、昵称、品种、近期体重及历史电子病史数据授权同步给您所选择的医疗机构商家。</p>
      <div class="highlight">医疗与保险理赔数据特别声明：在与保险公司理赔平台进行协作理赔时，我们仅在您主动发起索赔申请并签署授权书后，才会将宠物的医疗账单、处方单、诊断证明及芯片防伪验证数据传输至对接机构。</div>
    </section>

    <section>
      <h2>三、第三方开发套件使用规范</h2>
      <p>为保障 App 稳定运行以及提供 diagnostics 诊断基础设施，我们的 iOS/Rust 客户端集成相关自建或第三方组件。所有日志均经过脱敏，剔除 authorization、password、token 等隐私键值。</p>
    </section>

    <section>
      <h2>四、您的隐私控制权利</h2>
      <p>1. 查询、修改与删除：您有权随时在毛伙伴 App 中自主查询、修改宠物主页及记录时间线。</p>
      <p>2. 账号注销：如果您不再使用平台，可通过“我的-设置”申请注销账号。注销后，我们将停止提供协同记录服务，并按法律要求对相关数据进行匿名化处理或销毁。</p>
    </section>
  </main>
</body>
</html>
$privacy_policy$
) ON CONFLICT (kind) DO NOTHING;
