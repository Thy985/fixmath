import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import MathField from './src/components/MathField.jsx';

// 模拟 MathQuill
jest.mock('mathquill', () => {
  return {
    __esModule: true,
    default: {
      getInterface: jest.fn(() => {
        return {
          MathField: jest.fn(() => {
            return {
              latex: jest.fn((value) => {
                if (value) {
                  // 模拟设置值
                  return value;
                }
                // 模拟获取值
                return '\lim_{x \to 0} \frac{\sin x}{x} = 1';
              }),
              cursor: jest.fn(() => {
                return { pos: 0 };
              })
            };
          })
        };
      })
    }
  };
});

// 模拟 KaTeX
jest.mock('katex', () => {
  return {
    __esModule: true,
    default: {
      renderToString: jest.fn((formula) => {
        // 模拟 KaTeX 渲染成功
        if (formula.includes('\\') || formula.includes('_') || formula.includes('^')) {
          return `<span class="katex">${formula}</span>`;
        }
        // 模拟 KaTeX 渲染失败
        throw new Error('KaTeX parse error');
      })
    }
  };
});

// 测试 MathField 组件
describe('MathField Component', () => {
  test('renders correctly', () => {
    render(<MathField value="" onChange={() => {}} />);
    expect(screen.getByRole('textbox')).toBeInTheDocument();
  });

  test('handles paste event with valid formula', () => {
    const onChange = jest.fn();
    render(<MathField value="" onChange={onChange} />);
    
    const textarea = screen.getByRole('textbox');
    
    // 模拟粘贴事件
    fireEvent.paste(textarea, {
      preventDefault: jest.fn(),
      clipboardData: {
        getData: jest.fn(() => 'lim_{x to 0} frac{sin x}{x} = 1')
      }
    });
    
    // 验证 onChange 被调用
    expect(onChange).toHaveBeenCalled();
  });

  test('handles paste event with invalid formula', () => {
    const onChange = jest.fn();
    render(<MathField value="" onChange={onChange} />);
    
    const textarea = screen.getByRole('textbox');
    
    // 模拟粘贴普通文本
    fireEvent.paste(textarea, {
      preventDefault: jest.fn(),
      clipboardData: {
        getData: jest.fn(() => '普通文本内容，不是公式')
      }
    });
    
    // 验证 onChange 被调用
    expect(onChange).toHaveBeenCalled();
  });

  test('updates value when prop changes', () => {
    const onChange = jest.fn();
    const { rerender } = render(<MathField value="" onChange={onChange} />);
    
    // 重新渲染，更新 value
    rerender(<MathField value="\frac{1}{2}" onChange={onChange} />);
    
    // 验证组件能处理新的 value
    expect(onChange).not.toHaveBeenCalled();
  });

  test('focus state updates correctly', () => {
    render(<MathField value="" onChange={() => {}} />);
    
    const textarea = screen.getByRole('textbox');
    
    // 模拟聚焦事件
    fireEvent.focus(textarea);
    // 验证容器有 focused 类
    expect(textarea.parentElement).toHaveClass('focused');
    
    // 模拟失焦事件
    fireEvent.blur(textarea);
    // 验证容器没有 focused 类
    expect(textarea.parentElement).not.toHaveClass('focused');
  });
});

console.log('MathField 组件测试完成！');
