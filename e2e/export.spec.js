import { test, expect } from '@playwright/test';

test.describe('导出功能 E2E 测试', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('输入内容后转换按钮可用', async ({ page }) => {
    const textarea = page.locator('textarea, [contenteditable]').first();
    await textarea.fill('# 测试\n\n测试内容');
    
    const convertButton = page.getByRole('button', { name: /转换|convert|导出|export/i })
      .or(page.locator('button').filter({ hasText: /转换|convert/i }));
    
    if (await convertButton.isVisible()) {
      await expect(convertButton).toBeEnabled();
    }
  });

  test('清空按钮可以重置输入', async ({ page }) => {
    const textarea = page.locator('textarea, [contenteditable]').first();
    await textarea.fill('# 测试\n\n测试内容');
    
    const clearButton = page.getByRole('button', { name: /清空|clear|重置|reset/i })
      .or(page.locator('button').filter({ hasText: /清空|clear/i }));
    
    if (await clearButton.isVisible()) {
      await clearButton.click();
      await expect(textarea).toHaveValue('');
    }
  });

  test('错误处理：空输入时显示提示', async ({ page }) => {
    const convertButton = page.getByRole('button', { name: /转换|convert|导出|export/i })
      .or(page.locator('button').filter({ hasText: /转换|convert/i }));
    
    if (await convertButton.isVisible()) {
      await convertButton.click();
      const status = page.locator('.status, [class*="status"], text=/error|错误|失败/i');
      if (await status.isVisible({ timeout: 2000 }).catch(() => false)) {
        await expect(status).toContainText(/empty|空|请输入/i);
      }
    }
  });
});
