import { supabase } from '../lib/supabase';
import { startOfMonth, endOfMonth, subMonths, format, addDays, startOfDay, endOfDay } from 'date-fns';
import { saveAs } from 'file-saver';
import { utils, write } from 'xlsx';
import jsPDF from 'jspdf';
import 'jspdf-autotable';
import { DashboardMetrics, ChartData, UpcomingPickup } from '../types/database';

export const dashboardService = {
  async getTodayReturns(): Promise<UpcomingPickup[]> {
    try {
      const today = new Date();
      
      const { data, error } = await supabase
        .from('orders')
        .select(`
          id,
          order_number,
          return_date,
          return_time,
          total_amount,
          order_status,
          client:clients(
            id,
            name,
            phone,
            email,
            address
          ),
          items:order_items(
            quantity,
            unit_price,
            item:inventory_items(
              name,
              category
            )
          )
        `)
        .eq('return_date', today.toISOString().split('T')[0])
        .in('order_status', ['active', 'delayed'])
        .order('return_time', { ascending: true });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching today returns:', error);
      throw new Error('Failed to load today returns');
    }
  },

  async confirmReturn(orderId: string): Promise<void> {
    try {
      const { error } = await supabase
        .from('orders')
        .update({
          order_status: 'completed',
          updated_at: new Date().toISOString()
        })
        .eq('id', orderId);

      if (error) throw error;
    } catch (error) {
      console.error('Error confirming return:', error);
      throw new Error('Failed to confirm return');
    }
  },

  async getMetrics(startDate: Date, endDate: Date): Promise<DashboardMetrics> {
    try {
      const { data: orders, error: ordersError } = await supabase
        .from('orders')
        .select('*')
        .gte('created_at', startDate.toISOString())
        .lte('created_at', endDate.toISOString());

      if (ordersError) throw ordersError;

      const { data: transactions, error: transactionsError } = await supabase
        .from('transactions')
        .select('*')
        .gte('date', startDate.toISOString())
        .lte('date', endDate.toISOString());

      if (transactionsError) throw transactionsError;

      const totalOrders = orders?.length || 0;
      const completedOrders = orders?.filter(o => o.order_status === 'completed').length || 0;
      const canceledOrders = orders?.filter(o => o.order_status === 'canceled').length || 0;

      const revenue = transactions
        ?.filter(t => t.type === 'receita')
        .reduce((sum, t) => sum + t.amount, 0) || 0;

      const expenses = transactions
        ?.filter(t => t.type === 'despesa')
        .reduce((sum, t) => sum + t.amount, 0) || 0;

      const { data: customers } = await supabase
        .from('orders')
        .select('client_id')
        .gte('created_at', startOfMonth(subMonths(new Date(), 3)).toISOString());

      const returningCustomers = customers?.reduce((acc: { [key: string]: number }, order) => {
        acc[order.client_id] = (acc[order.client_id] || 0) + 1;
        return acc;
      }, {});

      const returningCount = Object.values(returningCustomers || {})
        .filter(count => count > 1)
        .length;

      const { data: availability } = await supabase
        .from('item_availability')
        .select('*')
        .gte('date', startDate.toISOString())
        .lte('date', endDate.toISOString());

      const occupationRate = availability
        ? (availability.reduce((sum, item) => sum + (item.reserved_quantity / (item.available_quantity + item.reserved_quantity) * 100), 0) / availability.length)
        : 0;

      const previousMonth = {
        start: startOfMonth(subMonths(startDate, 1)),
        end: endOfMonth(subMonths(endDate, 1))
      };

      const { data: previousOrders } = await supabase
        .from('orders')
        .select('*')
        .gte('created_at', previousMonth.start.toISOString())
        .lte('created_at', previousMonth.end.toISOString());

      const monthlyGrowth = previousOrders?.length
        ? ((totalOrders - previousOrders.length) / previousOrders.length) * 100
        : 0;

      return {
        totalOrders,
        completedOrders,
        canceledOrders,
        revenue,
        expenses,
        balance: revenue - expenses,
        occupationRate,
        returningCustomers: returningCount,
        monthlyGrowth
      };
    } catch (error) {
      console.error('Error fetching metrics:', error);
      throw new Error('Failed to load dashboard metrics');
    }
  },

  async getRevenueChart(months: number = 6): Promise<ChartData[]> {
    try {
      const endDate = endOfMonth(new Date());
      const startDate = startOfMonth(subMonths(new Date(), months - 1));

      const { data: transactions, error } = await supabase
        .from('transactions')
        .select('*')
        .gte('date', startDate.toISOString())
        .lte('date', endDate.toISOString())
        .order('date');

      if (error) throw error;

      const monthlyData: { [key: string]: { current: number; previous: number } } = {};

      transactions?.forEach(transaction => {
        const monthKey = format(new Date(transaction.date), 'yyyy-MM');
        
        if (!monthlyData[monthKey]) {
          monthlyData[monthKey] = { current: 0, previous: 0 };
        }

        if (transaction.type === 'receita') {
          monthlyData[monthKey].current += transaction.amount;
        }
      });

      return Object.entries(monthlyData).map(([date, values]) => ({
        date: format(new Date(date), 'MMM/yyyy'),
        value: values.current,
        previousValue: values.previous
      }));
    } catch (error) {
      console.error('Error fetching revenue chart:', error);
      throw new Error('Failed to load revenue chart');
    }
  },

  async getOccupationChart(days: number = 30): Promise<ChartData[]> {
    try {
      const endDate = new Date();
      const startDate = subMonths(endDate, 1);

      const { data: availability, error } = await supabase
        .from('item_availability')
        .select('*')
        .gte('date', startDate.toISOString())
        .lte('date', endDate.toISOString());

      if (error) throw error;

      const dailyData: { [key: string]: number } = {};

      availability?.forEach(record => {
        const dateKey = format(new Date(record.date), 'yyyy-MM-dd');
        const utilization = record.reserved_quantity / (record.available_quantity + record.reserved_quantity) * 100;
        dailyData[dateKey] = (dailyData[dateKey] || 0) + utilization;
      });

      return Object.entries(dailyData).map(([date, value]) => ({
        date: format(new Date(date), 'dd/MM'),
        value: Math.round(value * 100) / 100
      }));
    } catch (error) {
      console.error('Error fetching occupation chart:', error);
      throw new Error('Failed to load occupation chart');
    }
  },

  async getUpcomingPickups(): Promise<UpcomingPickup[]> {
    try {
      const today = new Date();
      const nextWeek = addDays(today, 7);

      const { data, error } = await supabase
        .from('orders')
        .select(`
          id,
          order_number,
          pickup_date,
          pickup_time,
          total_amount,
          order_status,
          client:clients(
            id,
            name,
            phone,
            email,
            address
          ),
          items:order_items(
            quantity,
            unit_price,
            item:inventory_items(
              name,
              category
            )
          )
        `)
        .gte('pickup_date', today.toISOString().split('T')[0])
        .lte('pickup_date', nextWeek.toISOString().split('T')[0])
        .eq('order_status', 'pending')
        .order('pickup_date', { ascending: true })
        .order('pickup_time', { ascending: true });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching upcoming pickups:', error);
      throw new Error('Failed to load upcoming pickups');
    }
  },

  async confirmPickup(orderId: string): Promise<void> {
    try {
      const { error } = await supabase
        .from('orders')
        .update({
          order_status: 'active',
          updated_at: new Date().toISOString()
        })
        .eq('id', orderId);

      if (error) throw error;
    } catch (error) {
      console.error('Error confirming pickup:', error);
      throw new Error('Failed to confirm pickup');
    }
  },

  async exportReport(format: 'pdf' | 'excel' | 'csv', startDate: Date, endDate: Date) {
    try {
      const metrics = await this.getMetrics(startDate, endDate);
      const revenueData = await this.getRevenueChart();

      const reportData = {
        metrics,
        revenueChart: revenueData,
        generatedAt: new Date().toISOString(),
        period: {
          start: startDate.toISOString(),
          end: endDate.toISOString()
        }
      };

      switch (format) {
        case 'pdf':
          return this.generatePDF(reportData);
        case 'excel':
          return this.generateExcel(reportData);
        case 'csv':
          return this.generateCSV(reportData);
      }
    } catch (error) {
      console.error('Error exporting report:', error);
      throw new Error('Failed to export report');
    }
  },

  generatePDF(data: any) {
    const doc = new jsPDF();

    doc.setFontSize(20);
    doc.text('Relatório de Desempenho', 20, 20);

    doc.setFontSize(12);
    doc.text(`Período: ${format(new Date(data.period.start), 'dd/MM/yyyy')} a ${format(new Date(data.period.end), 'dd/MM/yyyy')}`, 20, 30);

    const metricsData = [
      ['Métrica', 'Valor'],
      ['Total de Pedidos', data.metrics.totalOrders],
      ['Pedidos Concluídos', data.metrics.completedOrders],
      ['Receita Total', `R$ ${data.metrics.revenue.toFixed(2)}`],
      ['Despesas', `R$ ${data.metrics.expenses.toFixed(2)}`],
      ['Saldo', `R$ ${data.metrics.balance.toFixed(2)}`],
      ['Taxa de Ocupação', `${data.metrics.occupationRate.toFixed(1)}%`],
      ['Clientes Recorrentes', data.metrics.returningCustomers],
      ['Crescimento Mensal', `${data.metrics.monthlyGrowth.toFixed(1)}%`]
    ];

    (doc as any).autoTable({
      startY: 40,
      head: [metricsData[0]],
      body: metricsData.slice(1),
      theme: 'grid'
    });

    doc.save(`relatorio-${format(new Date(), 'yyyy-MM-dd')}.pdf`);
  },

  generateExcel(data: any) {
    const wb = utils.book_new();

    const metricsData = [
      ['Métrica', 'Valor'],
      ['Total de Pedidos', data.metrics.totalOrders],
      ['Pedidos Concluídos', data.metrics.completedOrders],
      ['Receita Total', data.metrics.revenue],
      ['Despesas', data.metrics.expenses],
      ['Saldo', data.metrics.balance],
      ['Taxa de Ocupação', data.metrics.occupationRate],
      ['Clientes Recorrentes', data.metrics.returningCustomers],
      ['Crescimento Mensal', data.metrics.monthlyGrowth]
    ];

    const metricsWs = utils.aoa_to_sheet(metricsData);
    utils.book_append_sheet(wb, metricsWs, 'Métricas');

    const revenueData = [
      ['Mês', 'Receita', 'Receita Anterior'],
      ...data.revenueChart.map((item: ChartData) => [
        item.date,
        item.value,
        item.previousValue
      ])
    ];

    const revenueWs = utils.aoa_to_sheet(revenueData);
    utils.book_append_sheet(wb, revenueWs, 'Receitas');

    const wbout = write(wb, { bookType: 'xlsx', type: 'array' });
    const blob = new Blob([wbout], { type: 'application/octet-stream' });
    saveAs(blob, `relatorio-${format(new Date(), 'yyyy-MM-dd')}.xlsx`);
  },

  generateCSV(data: any) {
    const csvData = [
      ['Relatório de Desempenho'],
      [`Período: ${format(new Date(data.period.start), 'dd/MM/yyyy')} a ${format(new Date(data.period.end), 'dd/MM/yyyy')}`],
      [],
      ['Métricas'],
      ['Métrica', 'Valor'],
      ['Total de Pedidos', data.metrics.totalOrders],
      ['Pedidos Concluídos', data.metrics.completedOrders],
      ['Receita Total', data.metrics.revenue],
      ['Despesas', data.metrics.expenses],
      ['Saldo', data.metrics.balance],
      ['Taxa de Ocupação', data.metrics.occupationRate],
      ['Clientes Recorrentes', data.metrics.returningCustomers],
      ['Crescimento Mensal', data.metrics.monthlyGrowth],
      [],
      ['Receitas por Mês'],
      ['Mês', 'Receita', 'Receita Anterior'],
      ...data.revenueChart.map((item: ChartData) => [
        item.date,
        item.value,
        item.previousValue
      ])
    ];

    const csvContent = csvData
      .map(row => row.join(','))
      .join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8' });
    saveAs(blob, `relatorio-${format(new Date(), 'yyyy-MM-dd')}.csv`);
  },

  generatePickupDocument(pickup: UpcomingPickup): void {
    const doc = new jsPDF();

    doc.setFontSize(20);
    doc.text('LocDecor', 20, 20);
    doc.setFontSize(10);
    doc.text('Aluguel de Decorações para Eventos', 20, 30);
    doc.text('Tel: (XX) XXXX-XXXX', 20, 35);
    doc.text('Email: contato@locdecor.com', 20, 40);

    doc.setFontSize(14);
    doc.text('Ordem de Retirada', 20, 55);
    
    doc.setFontSize(12);
    doc.text(`Pedido N° ${pickup.order_number}`, 20, 70);
    doc.text(`Data: ${format(new Date(pickup.pickup_date), 'dd/MM/yyyy')}`, 20, 80);
    doc.text(`Horário: ${pickup.pickup_time}`, 20, 90);
    
    doc.text('Dados do Cliente:', 20, 105);
    doc.setFontSize(10);
    doc.text(`Nome: ${pickup.client.name}`, 25, 115);
    if (pickup.client.phone) doc.text(`Telefone: ${pickup.client.phone}`, 25, 125);
    if (pickup.client.email) doc.text(`Email: ${pickup.client.email}`, 25, 135);
    if (pickup.client.address) doc.text(`Endereço: ${pickup.client.address}`, 25, 145);

    const tableData = pickup.items.map(item => [
      item.item.name,
      item.item.category,
      item.quantity.toString(),
      `R$ ${item.unit_price.toFixed(2)}`,
      `R$ ${(item.quantity * item.unit_price).toFixed(2)}`
    ]);

    (doc as any).autoTable({
      startY: 160,
      head: [['Item', 'Categoria', 'Qtd', 'Valor Unit.', 'Total']],
      body: tableData,
      theme: 'grid',
      headStyles: { fillColor: [139, 92, 246] }
    });

    const finalY = (doc as any).lastAutoTable.finalY;
    doc.text(`Valor Total: R$ ${pickup.total_amount.toFixed(2)}`, 20, finalY + 20);

    doc.text('_____________________', 20, finalY + 50);
    doc.text('Assinatura do Cliente', 20, finalY + 60);

    doc.text('_____________________', 120, finalY + 50);
    doc.text('Assinatura LocDecor', 120, finalY + 60);

    doc.save(`ordem-retirada-${pickup.order_number}.pdf`);
  }
};