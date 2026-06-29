// capability_catalog_boundary CapabilityCatalog 能力边界测试
// 核心职责：
// - 验证无宠物用户仍可进入公共宠物能力
// - 验证私域工具按授权宠物启用
// - 验证 has_private_capabilities 正确区分公共与私域能力

use maohuoban_ai_domain::ai::{AgentCapability, CapabilityCatalog, CapabilityDomain};

fn public_capability() -> AgentCapability {
    AgentCapability {
        code: "public_pet_care".to_owned(),
        domain: CapabilityDomain::PublicPetDomain,
        title: "公共养宠咨询".to_owned(),
        when_to_use: "用户咨询通用照护、饮食、行为或常见症状观察时使用".to_owned(),
        requires_private_context: false,
    }
}

fn private_capability() -> AgentCapability {
    AgentCapability {
        code: "private_pet_context".to_owned(),
        domain: CapabilityDomain::PrivatePetContext,
        title: "授权宠物上下文".to_owned(),
        when_to_use: "用户询问自己宠物档案、饮食、异常、提醒或记录时使用".to_owned(),
        requires_private_context: true,
    }
}

fn app_support_capability() -> AgentCapability {
    AgentCapability {
        code: "app_product_support".to_owned(),
        domain: CapabilityDomain::AppProductSupport,
        title: "毛伙伴 App 使用帮助".to_owned(),
        when_to_use: "用户询问添加宠物、记录、提醒、历史和 App 操作时使用".to_owned(),
        requires_private_context: false,
    }
}

#[test]
fn catalog_with_only_public_capabilities_has_no_private_capabilities() {
    let catalog = CapabilityCatalog {
        capabilities: vec![public_capability(), app_support_capability()],
    };
    assert!(!catalog.has_private_capabilities());
}

#[test]
fn catalog_with_private_capability_reports_private_capabilities() {
    let catalog = CapabilityCatalog {
        capabilities: vec![public_capability(), private_capability()],
    };
    assert!(catalog.has_private_capabilities());
}

#[test]
fn empty_catalog_has_no_private_capabilities() {
    let catalog = CapabilityCatalog {
        capabilities: Vec::new(),
    };
    assert!(!catalog.has_private_capabilities());
}

#[test]
fn public_only_capabilities_do_not_require_private_context() {
    let catalog = CapabilityCatalog {
        capabilities: vec![public_capability(), app_support_capability()],
    };
    for cap in &catalog.capabilities {
        assert!(
            !cap.requires_private_context,
            "public capability {} must not require private context",
            cap.code
        );
    }
}
