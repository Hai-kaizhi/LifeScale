import { Button, Result } from 'antd';

interface ErrorMessageProps {
  title?: string;
  subtitle?: string;
  onRetry?: () => void;
}

export function ErrorMessage({ title = '加载失败', subtitle, onRetry }: ErrorMessageProps) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '60px 0' }}>
      <Result
        status="error"
        title={title}
        subTitle={subtitle}
        extra={onRetry ? <Button type="primary" onClick={onRetry}>重试</Button> : undefined}
      />
    </div>
  );
}
