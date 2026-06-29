import { Spin } from 'antd';

export function LoadingSpinner({ tip = '加载中...' }: { tip?: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', padding: '80px 0' }}>
      <Spin size="large" description={tip}>
        <div style={{ padding: 50 }} />
      </Spin>
    </div>
  );
}
