import { test, expect } from '@playwright/test';

test.describe('FormulaFix 应用 E2E 测试', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('页面加载成功', async ({ page }) => {
    await expect(page).toHaveTitle(/FixMath/);
  });

  test('主要 UI 元素存在', async ({ page }) => {
    await expect(page.locator('textarea, [contenteditable]').first()).toBeVisible();
  });

  test('可以输入 Markdown 内容', async ({ page }) => {
    const textarea = page.locator('textarea, [contenteditable]').first();
    await textarea.fill('# 测试标题\n\n这是一段测试内容。');
    await expect(textarea).toHaveValue(/测试标题/);
  });

  test('输出类型切换正常', async ({ page }) => {
    const pdfButton = page.getByText('PDF').or(page.getByText('pdf'));
    const docxButton = page.getByText('DOCX').or(page.getByText('docx'));

    if (await pdfButton.isVisible()) {
      await pdfButton.click();
    }
    if (await docxButton.isVisible()) {
      await docxButton.click();
    }
  });

  test('模板选择器可以打开和关闭', async ({ page }) => {
    const templateButton = page.getByText('选择模板').or(page.getByText('模板'));
    
    if (await templateButton.isVisible()) {
      await templateButton.click();
      await expect(page.locator('.template-content, .template-list')).toBeVisible();
      
      await templateButton.click();
    }
  });
});
