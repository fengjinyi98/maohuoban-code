-- Update user agreement and privacy policy to match design drafts style and content
UPDATE legal_documents
SET html = $user_agreement$
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <style>
    :root {
      color-scheme: light;
      --primary:     #4F8CFF;
      --primary-lt:  #6BCBFF;
      --primary-dk:  #3A6FCC;
      --primary-bg:  rgba(79, 140, 255, 0.08);

      --bg:          #F7F9FC;
      --card:        rgba(255, 255, 255, 0.75);
      --card-solid:  #FFFFFF;
      --card-border: rgba(255, 255, 255, 0.6);
      --glass:       rgba(255, 255, 255, 0.6);

      --l1: #1A1D26;     /* primary text */
      --l2: #6E7681;     /* secondary */
      --l3: #9CA3AF;     /* tertiary */
      --l4: #D1D5DB;     /* quaternary */

      --sep: rgba(0,0,0,0.05);

      --r-sm: 8px;
      --r-md: 12px;
      --r-lg: 16px;
      --r-xl: 20px;
      --r-2xl: 24px;
      --r-full: 9999px;

      --s1: 4px;
      --s2: 8px;
      --s3: 12px;
      --s4: 16px;
      --s5: 20px;
      --s6: 24px;
      --s8: 32px;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, "SF Pro Display", "SF Pro Text", "PingFang SC", "Helvetica Neue", sans-serif;
      background: transparent;
      color: var(--l1);
      -webkit-font-smoothing: antialiased;
      padding: calc(env(safe-area-inset-top) + 20px) 20px 48px;
    }
    main {
      max-width: 100%;
      margin: 0 auto;
    }
    h1 {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
      margin-bottom: var(--s2);
      color: var(--l1);
    }
    .meta {
      font-size: 13px;
      color: var(--l3);
      border-bottom: 0.5px solid var(--sep);
      padding-bottom: var(--s4);
      margin-bottom: var(--s5);
      display: flex;
      gap: var(--s4);
    }
    .doc-body {
      font-size: 15px;
      line-height: 1.7;
      color: var(--l2);
    }
    .doc-intro {
      margin-bottom: var(--s5);
      font-weight: 500;
      color: var(--l1);
    }
    .doc-sec {
      margin-bottom: var(--s6);
    }
    .doc-sec-t {
      font-size: 18px;
      font-weight: 700;
      color: var(--l1);
      margin-bottom: var(--s3);
      display: flex;
      align-items: center;
      gap: var(--s2);
    }
    .doc-sec-t::before {
      content: '';
      display: inline-block;
      width: 3px;
      height: 15px;
      background: var(--primary);
      border-radius: var(--r-full);
    }
    .doc-para {
      margin-bottom: var(--s3);
    }
    .doc-list {
      margin-bottom: var(--s4);
      padding-left: var(--s5);
      color: var(--l2);
    }
    .doc-list li {
      margin-bottom: var(--s2);
      list-style-type: decimal;
    }
    .doc-highlight-box {
      background: var(--primary-bg);
      border-radius: var(--r-md);
      padding: var(--s4);
      margin: var(--s4) 0;
      border: 0.5px solid rgba(79, 140, 255, 0.15);
    }
    .doc-highlight-box p {
      font-size: 13.5px;
      color: var(--primary-dk);
      font-weight: 500;
      line-height: 1.6;
      margin: 0;
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
    <div class="doc-body">
      <p class="doc-intro">欢迎您使用毛伙伴（Maohuoban）平台服务！本用户服务协议（以下简称“本协议”）是由您与毛伙伴服务运营商之间就账号注册、服务使用及各项相关权益等事宜所订立的契约。请您在使用前务必认真阅读、充分理解各条款内容，特别是涉及免责、责任限制的加粗特别条款。</p>

      <div class="doc-sec">
        <h3 class="doc-sec-t">一、 账号注册与使用规范</h3>
        <p class="doc-para">1. 注册凭证与实名关联：本平台支持通过中国大陆有效手机号码一键获取验证码的方式进行注册。为符合实名制网络安全管理规定，用户完成短信验证登录后，即完成账号实名关联。</p>
        <p class="doc-para">2. 档案建立与管理：毛伙伴是一个以宠物主体为核心的协同记录平台。用户有权为自己合法饲养或托管的宠物建立独立的主页、健康档案和成长时间线。用户应对所上传的宠物头像、品种信息、接种证明等数据的真实性与合法性负责。</p>
        <p class="doc-para">3. 账号安全责任：用户应当妥善保管手机账号的验证信息，任何通过用户手机号验证完成的登录、建档、预定等操作行为，均视为用户本人的真实意志表达，其法律后果由用户本人承担。</p>
      </div>

      <div class="doc-sec">
        <h3 class="doc-sec-t">二、 宠物主体协同服务规则</h3>
        <p class="doc-para">1. 照护记录真实性：用户可在平台记录宠物食欲、精神、排泄及日常体重等生命数据，以便于多家庭成员共享或就医协同。用户需承诺上传的宠物数据属于客观真实记录，不得滥用此工具进行虚假商业营销或误导性传播。</p>
        <p class="doc-para">2. 同城就医与预约：当用户使用本平台提供的同城医院在线挂号、美容寄养等预定功能时，应遵守商家的预约规则 and 取消时限。由于用户个人原因导致爽约，商家有权按照既定规则扣除违约金。</p>
        
        <div class="doc-highlight-box">
          <p>重要提示：关于“活体交易担保保障”模块，平台仅作为信息服务与技术存管协同工具。为防范交易风险，所有押金与款项均直接进入持牌金融存管机构进行冻结。在确认宠物健康无误、疫苗证明符合约定前，资金不会划转给卖家。</p>
        </div>
      </div>

      <div class="doc-sec">
        <h3 class="doc-sec-t">三、 用户行为与内容规范</h3>
        <p class="doc-para">用户在使用毛伙伴服务过程中，发布的内容（包含但不限于宠物主页描述、健康科普动态、同窝寻亲信息等）必须遵守国家有关法律法规，严禁发布以下内容：</p>
        <ul class="doc-list">
          <li>侵害任何第三方名誉权、隐私权、肖像权或著作权等合法权益的言论或图片；</li>
          <li>违背社会公德，展示或宣扬虐待动物、遗弃动物或非法宠物繁育交易的信息；</li>
          <li>含有虚假虚构的宠物伤病求助，或带有诈骗倾向的筹款众筹链接。</li>
        </ul>
      </div>

      <div class="doc-sec">
        <h3 class="doc-sec-t">四、 平台免责声明</h3>
        <p class="doc-para">1. 健康及记录数据免责：平台提供的“今日照护”及“疫苗驱虫提醒”属于非诊疗性质的日常关爱辅助工具。用户在平台录入和展示的任何健康状态数据，不得替代专业执业兽医师的临床诊断。对于根据平台日常状态提醒而引发的宠物健康决策纠纷，平台不承担医疗损害赔偿责任。</p>
        <p class="doc-para">2. 第三方保险协同免责：平台直连的保险理赔协同接口仅作为便捷信息传输通道。具体的保险承保、费率计算、理赔核定等业务，均由对接的保险公司独立负责，理赔争议应依据保单与保险公司另行协商解决。</p>
      </div>
    </div>
  </main>
</body>
</html>
$user_agreement$
WHERE kind = 'user_agreement';

UPDATE legal_documents
SET html = $privacy_policy$
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <style>
    :root {
      color-scheme: light;
      --primary:     #4F8CFF;
      --primary-lt:  #6BCBFF;
      --primary-dk:  #3A6FCC;
      --primary-bg:  rgba(79, 140, 255, 0.08);

      --bg:          #F7F9FC;
      --card:        rgba(255, 255, 255, 0.75);
      --card-solid:  #FFFFFF;
      --card-border: rgba(255, 255, 255, 0.6);
      --glass:       rgba(255, 255, 255, 0.6);

      --l1: #1A1D26;     /* primary text */
      --l2: #6E7681;     /* secondary */
      --l3: #9CA3AF;     /* tertiary */
      --l4: #D1D5DB;     /* quaternary */

      --sep: rgba(0,0,0,0.05);

      --r-sm: 8px;
      --r-md: 12px;
      --r-lg: 16px;
      --r-xl: 20px;
      --r-2xl: 24px;
      --r-full: 9999px;

      --s1: 4px;
      --s2: 8px;
      --s3: 12px;
      --s4: 16px;
      --s5: 20px;
      --s6: 24px;
      --s8: 32px;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, "SF Pro Display", "SF Pro Text", "PingFang SC", "Helvetica Neue", sans-serif;
      background: transparent;
      color: var(--l1);
      -webkit-font-smoothing: antialiased;
      padding: calc(env(safe-area-inset-top) + 20px) 20px 48px;
    }
    main {
      max-width: 100%;
      margin: 0 auto;
    }
    h1 {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
      margin-bottom: var(--s2);
      color: var(--l1);
    }
    .meta {
      font-size: 13px;
      color: var(--l3);
      border-bottom: 0.5px solid var(--sep);
      padding-bottom: var(--s4);
      margin-bottom: var(--s5);
      display: flex;
      gap: var(--s4);
    }
    .doc-body {
      font-size: 15px;
      line-height: 1.7;
      color: var(--l2);
    }
    .doc-intro {
      margin-bottom: var(--s5);
      font-weight: 500;
      color: var(--l1);
    }
    .doc-sec {
      margin-bottom: var(--s6);
    }
    .doc-sec-t {
      font-size: 18px;
      font-weight: 700;
      color: var(--l1);
      margin-bottom: var(--s3);
      display: flex;
      align-items: center;
      gap: var(--s2);
    }
    .doc-sec-t::before {
      content: '';
      display: inline-block;
      width: 3px;
      height: 15px;
      background: var(--primary);
      border-radius: var(--r-full);
    }
    .doc-para {
      margin-bottom: var(--s3);
    }
    .doc-list {
      margin-bottom: var(--s4);
      padding-left: var(--s5);
      color: var(--l2);
    }
    .doc-list li {
      margin-bottom: var(--s2);
      list-style-type: decimal;
    }
    .doc-highlight-box {
      background: var(--primary-bg);
      border-radius: var(--r-md);
      padding: var(--s4);
      margin: var(--s4) 0;
      border: 0.5px solid rgba(79, 140, 255, 0.15);
    }
    .doc-highlight-box p {
      font-size: 13.5px;
      color: var(--primary-dk);
      font-weight: 500;
      line-height: 1.6;
      margin: 0;
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
    <div class="doc-body">
      <p class="doc-intro">毛伙伴（以下简称“我们”）致力于保护宠物主人和宠物健康相关个人隐私。在您使用毛伙伴平台提供的日常记录、健康诊断协作、同城预约及保险理赔协同等服务时，我们将按照本《隐私政策》收集、使用和共享您的个人与宠物隐私信息。我们建议您通读本协议以了解保护隐私的承诺。</p>

      <div class="doc-sec">
        <h3 class="doc-sec-t">一、 我们如何收集和使用信息</h3>
        <p class="doc-para">为了向您提供宠物管理及同城协作服务，我们将在以下场景中收集必要的信息：</p>
        <p class="doc-para">1. 基础注册与登录信息：在您注册或登录毛伙伴时，我们会收集您的手机号码，以此向您发送短信验证码。若您选择使用微信或 Apple 账户进行第三方登录，我们会在获得您的明确同意后，收集您的头像、昵称或唯一的 OpenID/User ID。</p>
        <p class="doc-para">2. 宠物基本与健康档案数据：为确保宠物主页及时间线功能的正常运作，您在创建宠物档案时需要上传或录入：宠物照片、昵称、品种、性别、生日、是否绝育等。此外，在日常照护中录入的食欲、排泄状态、体重波动以及历史诊断病史和接种凭证，均属于必要健康档案数据，仅用于记录和向您展示。</p>
        <p class="doc-para">3. 位置与同城服务信息：当您探索同城伙伴、搜寻附近的 verified 认证猫舍/犬舍或查看附近的宠物医院时，我们会在获得授权后收集您的地理位置（GPS）信息。该信息仅用于本地服务测距，我们不会对您的具体位置轨迹进行持续记录。</p>
      </div>

      <div class="doc-sec">
        <h3 class="doc-sec-t">二、 数据的共享、披露与协同规范</h3>
        <p class="doc-para">我们严格遵守“最小必要”的共享原则，仅在以下明确定义的协同场景下共享数据：</p>
        <p class="doc-para">1. 预约就诊协同：当您通过平台预约宠物医院、挂号或在线诊疗时，为便于主治兽医了解病情，我们会将您的宠物头像、昵称、品种、近期体重及历史电子病史数据授权同步给您所选择的医疗机构商家。</p>
        <p class="doc-para">2. 活体交易履约校验：在使用同城活体交易保障功能时，为确保履约安全性与追溯链条，平台会对猫舍/犬舍的资质认证以及宠物的健康疫苗记录进行验证，并仅在交易买家与卖家之间公开宠物必要的血缘与检验凭证，防止买卖双方欺诈行为。</p>
        
        <div class="doc-highlight-box">
          <p>医疗与保险理赔数据特别声明：在与保险公司理赔平台进行协作理赔时，我们仅在您主动发起索赔申请并签署授权书后，才会将宠物的医疗账单、处方单、诊断证明及芯片防伪验证数据传输至对接的保险协同机构。任何时候均不进行静默后台同步。</p>
        </div>
      </div>

      <div class="doc-sec">
        <h3 class="doc-sec-t">三、 第三方开发套件（SDK）使用规范</h3>
        <p class="doc-para">为保障 App 的稳定运行以及提供 diagnostics（诊断）基础设施，我们的 iOS/Rust 客户端集成了相关自建或第三方组件。我们收集的所有日志（如 app 启动崩溃记录、运行严重程度 Severity 以上事件）均经过脱敏，剔除了 authorization、password、token 等隐私键值。</p>
      </div>

      <div class="doc-sec">
        <h3 class="doc-sec-t">四、 您的隐私控制权利</h3>
        <p class="doc-para">1. 查询、修改与删除：您有权随时登录毛伙伴 App，在宠物世界、“我的”或设置模块中，自主查询、修改您的宠物主页及记录时间线。当您删除某一宠物档案或时间线节点时，平台将立即在前端隐藏，并在 7 个工作日内对服务器底层及备份数据库中的对应健康数据执行物理清除。</p>
        <p class="doc-para">2. 账号注销：如果您不再使用平台，可通过“我的-设置”申请注销账号。注销后，我们将停止为您提供所有协同记录服务，并按法律要求对所有相关的实名手机号和关联宠物数据进行匿名化处理或彻底销毁。</p>
      </div>
    </div>
  </main>
</body>
</html>
$privacy_policy$
WHERE kind = 'privacy_policy';
